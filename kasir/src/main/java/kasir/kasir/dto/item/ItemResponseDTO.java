package kasir.kasir.dto.item;

import java.time.LocalDateTime;
import kasir.kasir.Entities.Shift.Status;
import lombok.Data;

@Data
public class ItemResponseDTO {
    
    private int itemid;
    private String name;
    private int priceBuy;
    private int priceSell;
    private int quantity;
    private Status status;
    private LocalDateTime createdAt;
    private LocalDateTime updateAt;

}