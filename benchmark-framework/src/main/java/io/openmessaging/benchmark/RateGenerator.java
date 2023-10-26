package io.openmessaging.benchmark;

import lombok.extern.slf4j.Slf4j;

import java.time.LocalTime;
import java.util.Map;
import java.util.NavigableMap;
import java.util.TreeMap;

@Slf4j
public class RateGenerator {
    final private NavigableMap<LocalTime, Double> ratePoints = new TreeMap<>();

    public void put(LocalTime time, double rate) {
        ratePoints.put(time, rate);
    }

    public double get(LocalTime time) {
        if (ratePoints.isEmpty()) {
            return 0;
        }

        int floorTime, ceilingTime;
        double floorRate, ceilingRate;
        Map.Entry<LocalTime, Double> floorEntry = ratePoints.floorEntry(time);
        if (null == floorEntry) {
            floorTime = ratePoints.lastKey().toSecondOfDay() - 24 * 60 * 60;
            floorRate = ratePoints.lastEntry().getValue();
        } else {
            floorTime = floorEntry.getKey().toSecondOfDay();
            floorRate = floorEntry.getValue();
        }
        Map.Entry<LocalTime, Double> ceilingEntry = ratePoints.ceilingEntry(time);
        if (null == ceilingEntry) {
            ceilingTime = ratePoints.firstKey().toSecondOfDay() + 24 * 60 * 60;
            ceilingRate = ratePoints.firstEntry().getValue();
        } else {
            ceilingTime = ceilingEntry.getKey().toSecondOfDay();
            ceilingRate = ceilingEntry.getValue();
        }
        return calculateY(floorTime, floorRate, ceilingTime, ceilingRate, time.toSecondOfDay());
    }

    private double calculateY(int x1, double y1, int x2, double y2, int x) {
        if (x1 == x2) {
            return y1;
        }
        return y1 + (x - x1) * (y2 - y1) / (x2 - x1);
    }
}
