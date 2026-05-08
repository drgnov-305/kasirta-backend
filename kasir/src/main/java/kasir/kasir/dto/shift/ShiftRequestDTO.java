package kasir.kasir.dto.shift;

import kasir.kasir.Entities.Shift.Status;
import lombok.Data;

@Data
public class ShiftRequestDTO {

    private short userId; 
    private int income;
    private short solditem;
    private Status status;

}