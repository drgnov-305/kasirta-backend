package kasir.kasir.repository;

import kasir.kasir.Entities.User.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Short> {
    
    // Spring Data JPA secara otomatis akan membuatkan query SQL: 
    // SELECT * FROM users WHERE email = ?
    Optional<User> findByEmail(String email);

}