package kasir.kasir.dto.item;

import kasir.kasir.Entities.Shift.Status;
import lombok.Data;

@Data
public class ItemRequestDTO {
    
    private String name;
    private int priceBuy;
    private int priceSell;
    private int quantity;
    private Status status;

}