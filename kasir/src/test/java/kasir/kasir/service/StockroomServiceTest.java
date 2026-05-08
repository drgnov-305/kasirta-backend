package kasir.kasir.service;

import kasir.kasir.dto.stockroom.StockroomRequestDTO;
import kasir.kasir.Entities.User.Role;
import kasir.kasir.repository.StockroomRepository;
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
public class StockroomServiceTest {

    @Mock private StockroomRepository stockroomRepository;
    @InjectMocks private StockroomService stockroomService;
    private StockroomRequestDTO requestDTO;

    @BeforeEach
    void setUp() {
        requestDTO = new StockroomRequestDTO();
        requestDTO.setUserId((short) 2);
        requestDTO.setItemId(1);
        requestDTO.setQuantity("50");
    }

    @Test
    @DisplayName("CREATE: Kasir nyoba nyatet stok barang masuk -> DIBLOKIR")
    void recordStock_Fail_ByCashier() {
        Exception e = assertThrows(RuntimeException.class, () -> stockroomService.recordStock(requestDTO, (short) 1, Role.Cashier));
        assertEquals("Akses Ditolak: Hanya Gudang atau Owner yang dapat mencatat stok.", e.getMessage());
    }

    @Test
    @DisplayName("CREATE (MANIPULASI): Input Quantity pakai huruf (ABC) -> DIBLOKIR")
    void recordStock_Fail_StringQuantity() {
        requestDTO.setQuantity("LIMA");
        Exception e = assertThrows(RuntimeException.class, () -> stockroomService.recordStock(requestDTO, (short) 2, Role.WareHouse));
        assertEquals("Validasi Gagal: Format Quantity rusak. Harus berupa angka bulat.", e.getMessage());
    }

    @Test
    @DisplayName("CREATE (MANIPULASI): Input Quantity Minus -> DIBLOKIR")
    void recordStock_Fail_NegativeQuantity() {
        requestDTO.setQuantity("-10");
        Exception e = assertThrows(RuntimeException.class, () -> stockroomService.recordStock(requestDTO, (short) 2, Role.WareHouse));
        assertEquals("Validasi Gagal: Quantity tidak boleh minus untuk pencatatan masuk.", e.getMessage());
    }

    @Test
    @DisplayName("DELETE: Gudang nyoba hapus riwayat stok yang udah dicatat -> DIBLOKIR")
    void deleteStock_Fail_ByWareHouse() {
        Exception e = assertThrows(RuntimeException.class, () -> stockroomService.deleteStock(1, Role.WareHouse));
        assertEquals("Akses Ditolak Mutlak: Hanya Owner yang dapat menghapus log stok.", e.getMessage());
    }
}