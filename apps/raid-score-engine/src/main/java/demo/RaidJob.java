package demo;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.common.state.ValueState;
import org.apache.flink.api.common.state.ValueStateDescriptor;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.connector.base.DeliveryGuarantee;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.KeyedProcessFunction;
import org.apache.flink.util.Collector;

public class RaidJob {
    static final ObjectMapper JSON = new ObjectMapper();
    public static class Player extends KeyedProcessFunction<String,String,String> {
        private transient ValueState<Long> last, damage, combo;
        private final String version;
        public Player(String version) { this.version=version; }
        @Override public void open(Configuration c) {
            last=getRuntimeContext().getState(new ValueStateDescriptor<>("last-sequence",Long.class));
            damage=getRuntimeContext().getState(new ValueStateDescriptor<>("player-damage",Long.class));
            combo=getRuntimeContext().getState(new ValueStateDescriptor<>("combo",Long.class));
        }
        @Override public void processElement(String raw, Context ctx, Collector<String> out) throws Exception {
            ObjectNode e=(ObjectNode)JSON.readTree(raw);
            long seq=e.get("sequence").asLong(), prev=last.value()==null?0:last.value();
            boolean valid=seq==prev+1;
            long streak=combo.value()==null?0:combo.value();
            long total=damage.value()==null?0:damage.value();
            long applied=0;
            if(valid) {
                streak++;
                applied=e.get("damage").asLong() * (version.equals("v2") && streak%10==0?2:1);
                total+=applied;last.update(seq);combo.update(streak);damage.update(total);
            }
            e.put("valid",valid);e.put("appliedDamage",applied);e.put("playerDamage",total);
            e.put("combo",streak);e.put("lastSequence",valid?seq:prev);e.put("version",version);
            out.collect(e.toString());
        }
    }
    public static class Raid extends KeyedProcessFunction<String,String,String> {
        private transient ValueState<Long> damage, attacks, invalid;
        @Override public void open(Configuration c) {
            damage=getRuntimeContext().getState(new ValueStateDescriptor<>("total-damage",Long.class));
            attacks=getRuntimeContext().getState(new ValueStateDescriptor<>("total-attacks",Long.class));
            invalid=getRuntimeContext().getState(new ValueStateDescriptor<>("invalid-sequences",Long.class));
        }
        @Override public void processElement(String raw, Context ctx, Collector<String> out) throws Exception {
            ObjectNode e=(ObjectNode)JSON.readTree(raw);
            long d=(damage.value()==null?0:damage.value())+e.get("appliedDamage").asLong();
            long a=(attacks.value()==null?0:attacks.value())+1;
            long i=(invalid.value()==null?0:invalid.value())+(e.get("valid").asBoolean()?0:1);
            damage.update(d);attacks.update(a);invalid.update(i);
            e.put("totalDamage",d);e.put("totalAttacks",a);e.put("invalidSequenceCount",i);
            e.put("bossHp",Math.max(0,1000000000L-d));
            out.collect(e.toString());
        }
    }
    public static void main(String[] args) throws Exception {
        String version=System.getenv().getOrDefault("JOB_VERSION","v1");
        String brokers=System.getenv().getOrDefault("BOOTSTRAP","bossraid-kafka-bootstrap.kafka:9092");
        StreamExecutionEnvironment env=StreamExecutionEnvironment.getExecutionEnvironment();
        env.enableCheckpointing(5000);
        env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);
        env.setMaxParallelism(128);
        KafkaSource<String> source=KafkaSource.<String>builder().setBootstrapServers(brokers)
            .setTopics("bossraid-attacks").setGroupId("bossraid-score-engine")
            .setStartingOffsets(OffsetsInitializer.earliest()).setProperty("isolation.level","read_committed")
            .setValueOnlyDeserializer(new SimpleStringSchema()).build();
        var scored=env.fromSource(source,WatermarkStrategy.noWatermarks(),"combat-log").uid("combat-log")
            .keyBy(raw->JSON.readTree(raw).get("playerId").asText()).process(new Player(version)).uid("player-state")
            .keyBy(raw->"boss").process(new Raid()).setParallelism(1).uid("bossraid-state");
        for(String topic:new String[]{"bossraid-score-updates","bossraid-integrity"}) {
            scored.sinkTo(KafkaSink.<String>builder().setBootstrapServers(brokers)
                .setDeliveryGuarantee(DeliveryGuarantee.EXACTLY_ONCE)
                .setTransactionalIdPrefix(topic+"-txn-")
                .setProperty("transaction.timeout.ms","900000")
                .setRecordSerializer(KafkaRecordSerializationSchema.<String>builder().setTopic(topic)
                    .setKeySerializationSchema((String raw)-> {
                        try{return JSON.readTree(raw).get("playerId").asText().getBytes(java.nio.charset.StandardCharsets.UTF_8);}
                        catch(Exception e){throw new RuntimeException(e);}
                    }).setValueSerializationSchema(new SimpleStringSchema()).build()).build()).uid(topic+"-sink");
        }
        env.execute("bossraid-score-engine-"+version);
    }
}
