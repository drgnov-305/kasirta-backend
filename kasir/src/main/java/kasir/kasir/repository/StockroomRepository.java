package kasir.kasir.repository;

import kasir.kasir.Entities.Stockroom.Stockroom;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface StockroomRepository extends JpaRepository<Stockroom, Byte> {
}