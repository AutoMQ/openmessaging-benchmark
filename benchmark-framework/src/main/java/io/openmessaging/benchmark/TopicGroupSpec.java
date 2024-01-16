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
package io.openmessaging.benchmark;

import io.openmessaging.benchmark.utils.distributor.KeyDistributorType;

import java.util.List;

public class TopicGroupSpec {
    /** Name of the topic group. */
    public String groupName;
    /** Number of topics to create in the test. */
    public int topics;

    /** Number of partitions each topic will contain. */
    public int partitionsPerTopic;

    public KeyDistributorType keyDistributor = KeyDistributorType.NO_KEY;

    public int messageSize;

    public String payloadFile;

    public int subscriptionsPerTopic;
    public int consumerPerSubscription;

    public int producersPerTopic;

    public int producerRate;

    /**
     * If not null, producerRate will be ignored and the producer will use the list to set the rate at
     * different times. It supports two formats:
     * <li>[[hour, minute, rate], [hour, minute, rate], ...] - the rate will be set at the given hour
     *     and minute. For example, [[0, 0, 1000], [1, 30, 2000]] will set the rate to 1000 msg/s at
     *     00:00 and 2000 msg/s at 01:30.
     * <li>[[duration, rate], [duration, rate], ...] - the rate will be set at the given duration (in
     *     minutes) after the test starts. For example, [[0, 1000], [10, 2000], [20, 4000]] will set
     *     the rate to 1000 msg/s at the beginning, 2000 msg/s after 10 minutes, and 4000 msg/s after
     *     20 minutes (from the start of the test).
     */
    public List<List<Integer>> producerRateList = null;
}
