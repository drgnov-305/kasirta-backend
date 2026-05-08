package kasir.kasir.repository;

import kasir.kasir.Entities.Shift.Shift;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ShiftRepository extends JpaRepository<Shift, Byte> {
    // Contoh custom query untuk mencari shift berdasarkan ID User
    // List<Shift> findByUser_Userid(short userId);
}