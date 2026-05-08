package kasir.kasir.Entities.Stockroom;

import java.time.LocalDateTime;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import jakarta.persistence.*;
import kasir.kasir.Entities.Item.Item;
import kasir.kasir.Entities.User.User;
import kasir.kasir.Entities.Shift.Status;
import lombok.Data;

@Data
@Entity
@Table(name = "stockroom")
public class Stockroom {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "stockroom_id")
    private byte stockroomid;

    @CreationTimestamp
    @Column(name = "createdAt", updatable = false)
    private LocalDateTime createdAt; // ini creation dan update jangan dihapus emang gak perlu tapi kan memang harus ada 
    
    // Relasi Many-to-One ke User (Employee)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    // Relasi Many-to-One ke Item
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "item_id", nullable = false)
    private Item item;

    @Column(name = "quantity", nullable = false)
    private String quantity; // Sesuai kode Anda menggunakan String, namun disarankan diganti ke tipe numerik (int/short) di masa depan jika untuk kalkulasi

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private Status status;

    @UpdateTimestamp
    @Column(name = "updateAt")
    private LocalDateTime updateAt;

}