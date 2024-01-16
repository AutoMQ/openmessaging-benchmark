package io.openmessaging.benchmark.worker.commands;

public class RateAdjustInfo {
    public String topicGroup;
    public double publishRate;

    public RateAdjustInfo(String topicGroup, double publishRate) {
        this.topicGroup = topicGroup;
        this.publishRate = publishRate;
    }

    public RateAdjustInfo() {
    }
}
