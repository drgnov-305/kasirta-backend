package kasir.kasir.Entities.User;

import java.time.LocalDateTime;
import java.util.List;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import jakarta.persistence.*;
import lombok.Data;
import kasir.kasir.Entities.Shift.Shift;
import kasir.kasir.Entities.Stockroom.Stockroom;

@Data
@Entity
@Table(name = "users") 
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private short userid; // using short caused i just need a few employee 

    @CreationTimestamp
    @Column(name = "createdAt", updatable = false)
    private LocalDateTime createdAt; // ini creation dan update jangan dihapus emang gak perlu tapi kan memang harus ada 
    
    @Column(name = "name", nullable = false)
    private String name; 

    @Column(name = "age", nullable = true)
    private byte age; // byte caused you never life at 100+ lol

    @Column(name = "email", nullable = false)
    private String email; 

    @Column(name = "password", nullable = false)
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false)
    private Role role;

    @UpdateTimestamp
    @Column(name = "updateAt")
    private LocalDateTime updateAt;

    // Relasi One-to-Many ke Shift
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private List<Shift> shifts;

    // Relasi One-to-Many ke Stockroom
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private List<Stockroom> stockrooms;

}