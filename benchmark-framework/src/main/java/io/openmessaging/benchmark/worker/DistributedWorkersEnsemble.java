/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package io.openmessaging.benchmark.worker;

import static java.util.Collections.unmodifiableList;
import static java.util.stream.Collectors.joining;

import com.beust.jcommander.internal.Maps;
import com.google.common.annotations.VisibleForTesting;
import com.google.common.base.Preconditions;
import com.google.common.collect.Lists;
import io.openmessaging.benchmark.utils.ListPartition;
import io.openmessaging.benchmark.worker.commands.ConsumerAssignment;
import io.openmessaging.benchmark.worker.commands.CountersStats;
import io.openmessaging.benchmark.worker.commands.CumulativeLatencies;
import io.openmessaging.benchmark.worker.commands.DetailedTopic;
import io.openmessaging.benchmark.worker.commands.PeriodStats;
import io.openmessaging.benchmark.worker.commands.ProducerWorkAssignment;
import io.openmessaging.benchmark.worker.commands.RateAdjustInfo;
import io.openmessaging.benchmark.worker.commands.TopicSubscription;
import io.openmessaging.benchmark.worker.commands.TopicsInfo;
import java.io.File;
import java.io.IOException;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class DistributedWorkersEnsemble implements Worker {
    private final Thread shutdownHook = new Thread(this::stopAll);
    private final List<Worker> workers;
    private final List<Worker> producerWorkers;
    private final List<Worker> consumerWorkers;
    private final Worker leader;

    private Map<String, Set<Worker>> producerWorkersForTopicGroup = new ConcurrentHashMap<>();

    public DistributedWorkersEnsemble(
            List<Worker> workers, boolean extraConsumerWorkers, boolean separateWorkers) {
        this.workers = unmodifiableList(workers);
        leader = workers.get(0);
        if (separateWorkers) {
            Preconditions.checkArgument(workers.size() > 1);
            int numberOfProducerWorkers = getNumberOfProducerWorkers(workers, extraConsumerWorkers);
            List<List<Worker>> partitions =
                    Lists.partition(Lists.reverse(workers), workers.size() - numberOfProducerWorkers);
            this.producerWorkers = partitions.get(1);
            this.consumerWorkers = partitions.get(0);
        } else {
            this.producerWorkers = this.workers;
            this.consumerWorkers = this.workers;
        }

        log.info(
                "Workers list - producers: [{}]",
                producerWorkers.stream().map(Worker::id).collect(joining(",")));
        log.info(
                "Workers list - consumers: {}",
                consumerWorkers.stream().map(Worker::id).collect(joining(",")));

        Runtime.getRuntime().addShutdownHook(shutdownHook);
    }

    /*
     * For driver-jms extra consumers are required. If there is an odd number of workers then allocate the extra
     * to consumption.
     */
    @VisibleForTesting
    static int getNumberOfProducerWorkers(List<Worker> workers, boolean extraConsumerWorkers) {
        return extraConsumerWorkers ? (workers.size() + 2) / 3 : workers.size() / 2;
    }

    @Override
    public void initializeDriver(File configurationFile) throws IOException {
        workers.parallelStream()
                .forEach(
                        w -> {
                            try {
                                w.initializeDriver(configurationFile);
                            } catch (IOException e) {
                                throw new RuntimeException(e);
                            }
                        });
    }

    @Override
    @SuppressWarnings("unchecked")
    public List<String> createTopics(TopicsInfo topicsInfo) throws IOException {
        return leader.createTopics(topicsInfo);
    }

    @Override
    public void createProducers(List<DetailedTopic> detailedTopicList) {
        List<List<DetailedTopic>> topicsPerProducer =
                ListPartition.partitionList(detailedTopicList, producerWorkers.size());
        Map<Worker, List<DetailedTopic>> topicsPerWorkerMap = Maps.newHashMap();
        int i = 0;
        for (List<DetailedTopic> assignedTopics : topicsPerProducer) {
            Worker worker = producerWorkers.get(i++);
            topicsPerWorkerMap.put(worker, assignedTopics);
            assignedTopics.stream().map(t -> t.topicGroup).distinct().forEach(
                    topicGroup -> producerWorkersForTopicGroup.computeIfAbsent(
                            topicGroup, k -> new HashSet<>()).add(worker));
        }

        topicsPerWorkerMap.entrySet().parallelStream()
                .forEach(
                        e -> {
                            try {
                                e.getKey().createProducers(e.getValue());
                            } catch (IOException ex) {
                                throw new RuntimeException(ex);
                            }
                        });
    }

    @Override
    public void startLoad(ProducerWorkAssignment producerWorkAssignment) throws IOException {
        if (!producerWorkersForTopicGroup.containsKey(producerWorkAssignment.topicGroup)) {
            throw new RuntimeException("Topic group " + producerWorkAssignment.topicGroup + " not found");
        }
        double newRate = producerWorkAssignment.publishRate /
                producerWorkersForTopicGroup.get(producerWorkAssignment.topicGroup).size();
        log.debug("Setting worker assigned publish rate to {} msgs/sec", newRate);
        // Reduce the publish rate across all the brokers
        producerWorkersForTopicGroup.get(producerWorkAssignment.topicGroup).parallelStream()
                .forEach(
                        w -> {
                            try {
                                w.startLoad(producerWorkAssignment.withPublishRate(newRate));
                            } catch (IOException e) {
                                throw new RuntimeException(e);
                            }
                        });
    }

    @Override
    public void probeProducers() throws IOException {
        producerWorkers.parallelStream()
                .forEach(
                        w -> {
                            try {
                                w.probeProducers();
                            } catch (IOException e) {
                                throw new RuntimeException(e);
                            }
                        });
    }

    @Override
    public void adjustPublishRate(RateAdjustInfo rateAdjustInfo) throws IOException {
        if (!producerWorkersForTopicGroup.containsKey(rateAdjustInfo.topicGroup)) {
            throw new RuntimeException("Topic group " + rateAdjustInfo.topicGroup + " not found");
        }
        double newRate = rateAdjustInfo.publishRate /
                producerWorkersForTopicGroup.get(rateAdjustInfo.topicGroup).size();
        log.debug("Adjusting producer publish rate to {} msgs/sec", newRate);
        producerWorkers.parallelStream()
                .forEach(
                        w -> {
                            try {
                                w.adjustPublishRate(new RateAdjustInfo(rateAdjustInfo.topicGroup, newRate));
                            } catch (IOException e) {
                                throw new RuntimeException(e);
                            }
                        });
    }

    @Override
    public void stopAll() {
        workers.parallelStream().forEach(Worker::stopAll);
    }

    @Override
    public String id() {
        return "Ensemble[" + workers.stream().map(Worker::id).collect(joining(",")) + "]";
    }

    @Override
    public void pauseConsumers() throws IOException {
        consumerWorkers.parallelStream()
                .forEach(
                        w -> {
                            try {
                                w.pauseConsumers();
                            } catch (IOException e) {
                                throw new RuntimeException(e);
                            }
                        });
    }

    @Override
    public void resumeConsumers() throws IOException {
        consumerWorkers.parallelStream()
                .forEach(
                        w -> {
                            try {
                                w.resumeConsumers();
                            } catch (IOException e) {
                                throw new RuntimeException(e);
                            }
                        });
    }

    @Override
    public void createConsumers(ConsumerAssignment overallConsumerAssignment) {
        List<List<TopicSubscription>> subscriptionsPerConsumer =
                ListPartition.partitionList(
                        overallConsumerAssignment.topicsSubscriptions, consumerWorkers.size());
        Map<Worker, ConsumerAssignment> topicsPerWorkerMap = Maps.newHashMap();
        int i = 0;
        for (List<TopicSubscription> tsl : subscriptionsPerConsumer) {
            ConsumerAssignment individualAssignment = new ConsumerAssignment();
            individualAssignment.topicGroup = overallConsumerAssignment.topicGroup;
            individualAssignment.topicsSubscriptions = tsl;
            topicsPerWorkerMap.put(consumerWorkers.get(i++), individualAssignment);
        }
        topicsPerWorkerMap.entrySet().parallelStream()
                .forEach(
                        e -> {
                            try {
                                e.getKey().createConsumers(e.getValue());
                            } catch (IOException ex) {
                                throw new RuntimeException(ex);
                            }
                        });
    }

    @Override
    public PeriodStats getPeriodStats() {
        return workers.parallelStream()
                .map(
                        w -> {
                            try {
                                return w.getPeriodStats();
                            } catch (IOException e) {
                                throw new RuntimeException(e);
                            }
                        })
                .reduce(new PeriodStats(), PeriodStats::plus);
    }

    @Override
    public CumulativeLatencies getCumulativeLatencies() {
        return workers.parallelStream()
                .map(
                        w -> {
                            try {
                                return w.getCumulativeLatencies();
                            } catch (IOException e) {
                                throw new RuntimeException(e);
                            }
                        })
                .reduce(new CumulativeLatencies(), CumulativeLatencies::plus);
    }

    @Override
    public CountersStats getCountersStats() throws IOException {
        return workers.parallelStream()
                .map(
                        w -> {
                            try {
                                return w.getCountersStats();
                            } catch (IOException e) {
                                throw new RuntimeException(e);
                            }
                        })
                .reduce(new CountersStats(), CountersStats::plus);
    }

    @Override
    public void resetStats() throws IOException {
        workers.parallelStream()
                .forEach(
                        w -> {
                            try {
                                w.resetStats();
                            } catch (IOException e) {
                                throw new RuntimeException(e);
                            }
                        });
    }

    @Override
    public void close() throws Exception {
        Runtime.getRuntime().removeShutdownHook(shutdownHook);
        for (Worker w : workers) {
            try {
                w.close();
            } catch (Exception ignored) {
                log.trace("Ignored error while closing worker {}", w, ignored);
            }
        }
    }

    private static final Logger log = LoggerFactory.getLogger(DistributedWorkersEnsemble.class);
}
