import com.mongodb.client.*;
import org.bson.Document;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

public class MongoLoadTester {

    private static final int[] TPS_LEVELS = {100, 200, 500, 1000};
    private static final int DURATION_PER_LEVEL_SECONDS = 30;
    private static final int THREAD_COUNT = 100;

    private static MongoCollection<Document> collection;
    private static List<String> accountNumbers;

    private static List<Map<String, Object>> report = new ArrayList<>();

    public static void main(String[] args) throws Exception {
        MongoClient client = MongoClients.create("mongodb://localhost:27017");
        collection = client.getDatabase("testdb").getCollection("accounts");
        accountNumbers = Files.readAllLines(Paths.get("sample_accounts.txt"));
        Random rand = new Random();

        for (int tps : TPS_LEVELS) {
            System.out.println("\n🚀 Testing at " + tps + " TPS...");
            AtomicInteger success = new AtomicInteger();
            List<Long> latencies = Collections.synchronizedList(new ArrayList<>());

            ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(THREAD_COUNT);
            long intervalMicros = 1_000_000L / tps;
            int totalRequests = DURATION_PER_LEVEL_SECONDS * tps;

            Runnable task = () -> {
                String acc = accountNumbers.get(rand.nextInt(accountNumbers.size()));
                long start = System.nanoTime();
                try {
                    Document doc = collection.find(new Document("accountNumber", acc)).first();
                    if (doc != null) success.incrementAndGet();
                    long latency = (System.nanoTime() - start) / 1_000; // microseconds
                    latencies.add(latency);
                } catch (Exception e) {
                    System.err.println("Query error: " + e.getMessage());
                }
            };

            long startTime = System.currentTimeMillis();
            for (int i = 0; i < totalRequests; i++) {
                scheduler.schedule(task, i * intervalMicros, TimeUnit.MICROSECONDS);
            }

            scheduler.shutdown();
            scheduler.awaitTermination(DURATION_PER_LEVEL_SECONDS + 5, TimeUnit.SECONDS);
            long totalTime = System.currentTimeMillis() - startTime;

            double avgLatency = latencies.stream().mapToLong(l -> l).average().orElse(0) / 1000.0;
            long minLatency = latencies.stream().mapToLong(l -> l).min().orElse(0) / 1000;
            long maxLatency = latencies.stream().mapToLong(l -> l).max().orElse(0) / 1000;

            int total = latencies.size();
            long actualTps = total * 1000L / totalTime;

            System.out.printf("✅ Success: %d, Actual TPS: %d, Avg Latency: %.2f ms%n", success.get(), actualTps, avgLatency);

            Map<String, Object> result = new LinkedHashMap<>();
            result.put("Target TPS", tps);
            result.put("Actual TPS", actualTps);
            result.put("Success", success.get());
            result.put("Avg Latency (ms)", avgLatency);
            result.put("Min Latency (ms)", minLatency);
            result.put("Max Latency (ms)", maxLatency);
            report.add(result);
        }

        writeCsvReport("mongo_load_report.csv");
        System.out.println("\n📄 Report saved to mongo_load_report.csv");
    }

    private static void writeCsvReport(String filename) throws IOException {
        try (PrintWriter writer = new PrintWriter(Files.newBufferedWriter(Paths.get(filename)))) {
            List<String> headers = new ArrayList<>(report.get(0).keySet());
            writer.println(String.join(",", headers));
            for (Map<String, Object> row : report) {
                List<String> values = new ArrayList<>();
                for (String key : headers) {
                    values.add(row.get(key).toString());
                }
                writer.println(String.join(",", values));
            }
        }
    }
}