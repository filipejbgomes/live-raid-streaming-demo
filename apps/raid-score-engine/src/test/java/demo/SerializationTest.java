package demo;
import org.junit.Test;
import static org.junit.Assert.*;
public class SerializationTest {
    @Test public void eventJsonRoundTrip() throws Exception {
        var event=RaidJob.JSON.createObjectNode().put("playerId","player-1").put("sequence",10L).put("damage",17L);
        assertEquals(10L,RaidJob.JSON.readTree(event.toString()).get("sequence").asLong());
        assertEquals("player-1",RaidJob.JSON.readTree(event.toString()).get("playerId").asText());
    }
}
