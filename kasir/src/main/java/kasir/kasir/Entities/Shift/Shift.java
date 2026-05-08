package kasir.kasir.Entities.Shift;
import java.time.LocalDateTime;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import jakarta.persistence.*;
import lombok.Data;
import kasir.kasir.Entities.User.User;

@Data
@Entity
@Table(name = "shift")
public class Shift {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "shift_id")
    private byte shiftid;

    @CreationTimestamp
    @Column(name = "createdAt", updatable = false)
    private LocalDateTime createdAt; // ini creation dan update jangan dihapus emang gak perlu tapi kan memang harus ada 
    
    // Relasi Many-to-One ke User (Employee)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "income", nullable = true)
    private int income; // just used int there never will be i got Trillions (really on my life)

    @Column(name = "sold_item", nullable = false)
    private short solditem; 

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private Status status;

    @UpdateTimestamp
    @Column(name = "updateAt")
    private LocalDateTime updateAt;

}