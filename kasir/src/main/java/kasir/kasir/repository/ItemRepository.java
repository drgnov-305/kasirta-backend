package kasir.kasir.repository;

import kasir.kasir.Entities.Item.Item;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ItemRepository extends JpaRepository<Item, Integer> {
    // Anda bisa menambahkan custom query di sini nanti jika dibutuhkan
    // Contoh: List<Item> findByNameContainingIgnoreCase(String name);
}