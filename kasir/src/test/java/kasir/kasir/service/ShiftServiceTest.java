package kasir.kasir.service;

import kasir.kasir.dto.shift.ShiftRequestDTO;
import kasir.kasir.Entities.User.Role;
import kasir.kasir.repository.ShiftRepository;
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
public class ShiftServiceTest {

    @Mock private ShiftRepository shiftRepository;
    @InjectMocks private ShiftService shiftService;
    private ShiftRequestDTO requestDTO;

    @BeforeEach
    void setUp() {
        requestDTO = new ShiftRequestDTO();
        requestDTO.setUserId((short) 1);
        requestDTO.setIncome(500000);
        requestDTO.setSolditem((short) 50);
    }

    @Test
    @DisplayName("CREATE: Gudang coba buka Shift Kasir -> DIBLOKIR")
    void openShift_Fail_ByWareHouse() {
        Exception e = assertThrows(RuntimeException.class, () -> shiftService.openShift(requestDTO, (short) 2, Role.WareHouse));
        assertEquals("Akses Ditolak: Hanya Kasir yang dapat membuka Shift kerja.", e.getMessage());
    }

    @Test
    @DisplayName("CREATE (FRAUD): Setoran Income Minus -> DIBLOKIR")
    void openShift_Fail_NegativeIncome() {
        requestDTO.setIncome(-100000);
        Exception e = assertThrows(RuntimeException.class, () -> shiftService.openShift(requestDTO, (short) 1, Role.Cashier));
        assertEquals("Validasi Gagal: Pemasukan (Income) tidak valid/minus.", e.getMessage());
    }

    @Test
    @DisplayName("READ (PRIVASI): Kasir ngintip Shift milik Kasir lain -> DIBLOKIR")
    void getShift_Fail_CashierPeeksOther() {
        // Asumsi Shift ID 1 itu milik user ID 5, tapi yang request user ID 1
        Exception e = assertThrows(RuntimeException.class, () -> shiftService.getShiftById((byte) 1, (short) 1, Role.Cashier));
        assertEquals("Akses Ditolak: Anda hanya bisa melihat laporan Shift Anda sendiri.", e.getMessage());
    }

    @Test
    @DisplayName("UPDATE: Gudang ngedit riwayat Kasir -> DIBLOKIR")
    void updateShift_Fail_ByWareHouse() {
        Exception e = assertThrows(RuntimeException.class, () -> shiftService.updateShift((byte) 1, requestDTO, (short) 2, Role.WareHouse));
        assertEquals("Akses Ditolak: Hanya Kasir terkait atau Owner yang dapat mengedit Shift.", e.getMessage());
    }

    @Test
    @DisplayName("DELETE: Kasir hapus jejak Shift/Korupsi -> DIBLOKIR")
    void deleteShift_Fail_ByCashier() {
        Exception e = assertThrows(RuntimeException.class, () -> shiftService.deleteShift((byte) 1, Role.Cashier));
        assertEquals("Akses Ditolak Mutlak: Penghapusan Shift hanya dapat dilakukan oleh Owner.", e.getMessage());
    }
}