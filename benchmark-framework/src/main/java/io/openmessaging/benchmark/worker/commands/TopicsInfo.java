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
package io.openmessaging.benchmark.worker.commands;


import java.util.List;

import static io.openmessaging.benchmark.Workload.DEFAULT_TOPIC_GROUP;

public class TopicsInfo {
    public String groupName;
    public int numberOfTopics;
    public int numberOfPartitionsPerTopic;
    public List<Integer> numberOfPartitionsPerTopicList;
    public boolean randomName;

    public TopicsInfo() {}

    public TopicsInfo(
            int numberOfTopics,
            int numberOfPartitionsPerTopic,
            List<Integer> numberOfPartitionsPerTopicList,
            boolean randomName) {
        this(DEFAULT_TOPIC_GROUP, numberOfTopics, numberOfPartitionsPerTopic,
                numberOfPartitionsPerTopicList, randomName);
    }

    public TopicsInfo(
            String groupName,
            int numberOfTopics,
            int numberOfPartitionsPerTopic,
            List<Integer> numberOfPartitionsPerTopicList,
            boolean randomName) {
        this.groupName = groupName;
        this.numberOfTopics = numberOfTopics;
        this.numberOfPartitionsPerTopic = numberOfPartitionsPerTopic;
        this.numberOfPartitionsPerTopicList = numberOfPartitionsPerTopicList;
        this.randomName = randomName;
    }
}
