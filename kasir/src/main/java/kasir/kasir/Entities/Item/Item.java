package kasir.kasir.Entities.Item;
import java.time.LocalDateTime;
import java.util.List;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import jakarta.persistence.*;
import kasir.kasir.Entities.Stockroom.Stockroom;
import kasir.kasir.Entities.Shift.Status;
import lombok.Data;

@Data
@Entity
@Table(name = "item")
public class Item {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "item_id")
    private int itemid;

    @CreationTimestamp
    @Column(name = "createdAt", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "price_buy", nullable = false)
    private int priceBuy;

    @Column(name = "price_sell", nullable = false)
    private int priceSell;

    @Column(name = "quantity", nullable = false)
    private int quantity;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private Status status;

    @UpdateTimestamp
    @Column(name = "updateAt")
    private LocalDateTime updateAt;

    // Relasi One-to-Many ke Stockroom
    @OneToMany(mappedBy = "item", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private List<Stockroom> stockrooms;

}