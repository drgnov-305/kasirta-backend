package kasir.kasir.dto.stockroom;

import kasir.kasir.Entities.Shift.Status;
import lombok.Data;

@Data
public class StockroomRequestDTO {

    private short userId; 
    private int itemId;   
    private String quantity; 
    private Status status;

}