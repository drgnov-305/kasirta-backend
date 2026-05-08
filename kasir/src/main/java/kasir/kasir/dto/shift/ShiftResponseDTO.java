package kasir.kasir.dto.shift;

import java.time.LocalDateTime;
import kasir.kasir.Entities.Shift.Status;
import lombok.Data;

@Data
public class ShiftResponseDTO {

    private byte shiftid;
    private short userId; 
    private int income;
    private short solditem;
    private Status status;
    private LocalDateTime createdAt;
    private LocalDateTime updateAt;

}