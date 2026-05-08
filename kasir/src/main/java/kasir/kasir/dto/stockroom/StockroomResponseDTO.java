package kasir.kasir.dto.stockroom;

import java.time.LocalDateTime;
import kasir.kasir.Entities.Shift.Status;
import lombok.Data;

@Data
public class StockroomResponseDTO {

    private byte stockroomid;
    private short userId; 
    private int itemId;   
    private String quantity; 
    private Status status;
    private LocalDateTime createdAt;
    private LocalDateTime updateAt;

}