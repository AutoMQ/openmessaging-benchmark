package io.openmessaging.benchmark.worker.commands;

public class DetailedTopic {
    public String topic;
    public String topicGroup;
    public DetailedTopic(String topic, String topicGroup) {
        this.topic = topic;
        this.topicGroup = topicGroup;
    }

    public DetailedTopic() {}
}
