package kasir.kasir.service;

import kasir.kasir.dto.transaction.TransactionRequestDTO;
import kasir.kasir.Entities.User.Role;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

@ExtendWith(MockitoExtension.class)
public class TransactionServiceTest {

    // KITA CUMA INJECT SERVICE-NYA.
    // Mock Repository sengaja gw buang dulu biar GAK ADA WARNING KUNING!
    @InjectMocks
    private TransactionService transactionService;

    private TransactionRequestDTO requestDTO;

    @BeforeEach
    void setUp() {
        requestDTO = new TransactionRequestDTO();
        requestDTO.setItemId(1);
        requestDTO.setQuantity(2);
        requestDTO.setPaymentMethod("CASH");
        requestDTO.setAmountPaid(50000);
        requestDTO.setShiftId((byte) 1);
    }

    @Test
    @DisplayName("CHECKOUT (EXPLOIT CROSS-ROLE): Gudang nyoba jualan di mesin kasir -> DIBLOKIR")
    void processCheckout_Fail_ByWareHouse() {
        Exception e = assertThrows(RuntimeException.class, () -> transactionService.processCheckout(requestDTO, Role.WareHouse, (short) 2));
        assertEquals("Akses Ditolak: Hanya Kasir yang diizinkan memproses transaksi pembayaran.", e.getMessage());
    }

    @Test
    @DisplayName("CHECKOUT (NULL BOMB): Payload kosong disuntikkan -> DIBLOKIR")
    void processCheckout_Fail_NullRequest() {
        Exception e = assertThrows(RuntimeException.class, () -> transactionService.processCheckout(null, Role.Cashier, (short) 1));
        assertEquals("Validasi Gagal: Data transaksi tidak boleh kosong.", e.getMessage());
    }

    @Test
    @DisplayName("CHECKOUT (VALIDASI): Quantity belanja minus atau nol -> DIBLOKIR")
    void processCheckout_Fail_ZeroQuantity() {
        requestDTO.setQuantity(0);
        Exception e = assertThrows(RuntimeException.class, () -> transactionService.processCheckout(requestDTO, Role.Cashier, (short) 1));
        assertEquals("Validasi Gagal: Jumlah barang yang dibeli harus lebih dari nol.", e.getMessage());
    }

    @Test
    @DisplayName("CHECKOUT (PAYMENT EXPLOIT): Metode bayar di-hack pake 'KTP' -> DIBLOKIR")
    void processCheckout_Fail_InvalidPaymentMethod() {
        requestDTO.setPaymentMethod("KTP"); // Metode bayar halu
        Exception e = assertThrows(RuntimeException.class, () -> transactionService.processCheckout(requestDTO, Role.Cashier, (short) 1));
        assertEquals("Transaksi Gagal: Metode pembayaran tidak valid (Gunakan CASH, QRIS, atau E-WALLET).", e.getMessage());
    }

    @Test
    @DisplayName("CHECKOUT (RUGI BANDAR): Uang pelanggan KURANG dari total belanja -> DIBLOKIR")
    void processCheckout_Fail_InsufficientFunds() {
        requestDTO.setAmountPaid(1000); // Ngasih duit seribu perak doang
        Exception e = assertThrows(RuntimeException.class, () -> transactionService.processCheckout(requestDTO, Role.Cashier, (short) 1));
        assertEquals("Transaksi Gagal: Uang pembayaran tidak mencukupi (Ngutang tidak diizinkan).", e.getMessage());
    }

    @Test
    @DisplayName("CHECKOUT (LOGIC): Kasir memproses barang yang STOK-NYA HABIS -> DIBLOKIR")
    void processCheckout_Fail_OutOfStock() {
        requestDTO.setQuantity(5000); // Beli 5000 biji, sengaja dibikin jebol
        Exception e = assertThrows(RuntimeException.class, () -> transactionService.processCheckout(requestDTO, Role.Cashier, (short) 1));
        assertEquals("Transaksi Gagal: Stok barang tidak mencukupi untuk permintaan ini.", e.getMessage());
    }
}