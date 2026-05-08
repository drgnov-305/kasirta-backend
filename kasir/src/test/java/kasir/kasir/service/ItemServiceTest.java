package kasir.kasir.service;

import kasir.kasir.dto.item.ItemRequestDTO;
import kasir.kasir.Entities.User.Role;
import kasir.kasir.repository.ItemRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

@ExtendWith(MockitoExtension.class)
public class ItemServiceTest {

    @Mock private ItemRepository itemRepository;
    @InjectMocks private ItemService itemService;
    private ItemRequestDTO requestDTO;

    @BeforeEach
    void setUp() {
        requestDTO = new ItemRequestDTO();
        requestDTO.setName("Rokok Surya");
        requestDTO.setPriceBuy(20000);
        requestDTO.setPriceSell(25000);
        requestDTO.setQuantity(100);
    }

    @Test
    @DisplayName("CREATE: Kasir nambah barang master -> DIBLOKIR")
    void createItem_Fail_ByCashier() {
        Exception e = assertThrows(RuntimeException.class, () -> itemService.createItem(requestDTO, Role.Cashier));
        assertEquals("Akses Ditolak: Hanya Owner yang dapat menambah Master Barang.", e.getMessage());
    }

    @Test
    @DisplayName("CREATE (RUGI BANDAR): Harga Jual < Harga Beli -> DIBLOKIR")
    void createItem_Fail_LossPrevention() {
        requestDTO.setPriceSell(15000); // Beli 20k, Jual 15k
        Exception e = assertThrows(RuntimeException.class, () -> itemService.createItem(requestDTO, Role.Owner));
        assertEquals("Logika Bisnis Gagal: Harga jual tidak boleh lebih kecil dari harga beli.", e.getMessage());
    }

    @Test
    @DisplayName("CREATE (VALIDASI): Harga Beli Minus -> DIBLOKIR")
    void createItem_Fail_NegativePrice() {
        requestDTO.setPriceBuy(-5000);
        Exception e = assertThrows(RuntimeException.class, () -> itemService.createItem(requestDTO, Role.Owner));
        assertEquals("Validasi Gagal: Harga tidak boleh minus.", e.getMessage());
    }

    @Test
    @DisplayName("UPDATE: Gudang update harga barang -> DIBLOKIR")
    void updateItem_Fail_ByWareHouse() {
        Exception e = assertThrows(RuntimeException.class, () -> itemService.updateItem(1, requestDTO, Role.WareHouse));
        assertEquals("Akses Ditolak: Hanya Owner yang berhak mengubah harga/data Master Barang.", e.getMessage());
    }

    @Test
    @DisplayName("DELETE: Kasir hapus Master Barang -> DIBLOKIR")
    void deleteItem_Fail_ByCashier() {
        Exception e = assertThrows(RuntimeException.class, () -> itemService.deleteItem(1, Role.Cashier));
        assertEquals("Akses Ditolak Mutlak: Hanya Owner yang dapat menghapus Master Barang.", e.getMessage());
    }
}