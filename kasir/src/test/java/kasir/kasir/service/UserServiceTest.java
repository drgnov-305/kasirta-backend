package kasir.kasir.service;

import kasir.kasir.dto.user.UserRequestDTO;
import kasir.kasir.dto.user.UserResponseDTO;
import kasir.kasir.Entities.User.Role;
import kasir.kasir.Entities.User.User;
import kasir.kasir.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserService userService;

    private UserRequestDTO requestDTO;
    private User dummyUser;

    @BeforeEach
    void setUp() {
        requestDTO = new UserRequestDTO();
        requestDTO.setName("Budi Kasir");
        requestDTO.setAge((byte) 25);
        requestDTO.setEmail("budi@kasir.com");
        requestDTO.setPassword("rahasia123");
        requestDTO.setRole(Role.Cashier);

        dummyUser = new User();
        dummyUser.setUserid((short) 1);
        dummyUser.setName("Budi Kasir");
        dummyUser.setAge((byte) 25);
        dummyUser.setEmail("budi@kasir.com");
        dummyUser.setPassword("rahasia123");
        dummyUser.setRole(Role.Cashier);
    }

    // ===================================================================================
    // 1. C.R.U.D - CREATE (REGISTER) TESTS
    // ===================================================================================

    @Test
    @DisplayName("CREATE: Sukses jika Owner mendaftarkan Pegawai")
    void registerUser_Success_OwnerRegistersUser() {
        when(userRepository.findByEmail(anyString())).thenReturn(Optional.empty());
        when(userRepository.save(any(User.class))).thenReturn(dummyUser);

        UserResponseDTO response = userService.registerUser(requestDTO, Role.Owner);
        assertNotNull(response);
    }

    @Test
    @DisplayName("CREATE (EXPLOIT): Kasir mendaftarkan user baru -> DIBLOKIR")
    void registerUser_Fail_CashierTriesToRegister() {
        Exception exception = assertThrows(RuntimeException.class, () -> userService.registerUser(requestDTO, Role.Cashier));
        assertEquals("Akses Ditolak: Hanya Owner yang dapat mendaftarkan pegawai baru.", exception.getMessage());
    }

    @Test
    @DisplayName("CREATE (VALIDASI): Owner mendaftarkan email duplikat -> DIBLOKIR")
    void registerUser_Fail_DuplicateEmail() {
        when(userRepository.findByEmail(anyString())).thenReturn(Optional.of(dummyUser));
        Exception exception = assertThrows(RuntimeException.class, () -> userService.registerUser(requestDTO, Role.Owner));
        assertEquals("Gagal: Email sudah terdaftar di sistem.", exception.getMessage());
    }

    @Test
    @DisplayName("CREATE (EXPLOIT/XSS): Nama mengandung script berbahaya -> DIBLOKIR")
    void registerUser_Fail_XssInjectionInName() {
        requestDTO.setName("<script>alert('HACKED')</script>");
        Exception exception = assertThrows(RuntimeException.class, () -> userService.registerUser(requestDTO, Role.Owner));
        assertEquals("Validasi Gagal: Nama mengandung karakter ilegal.", exception.getMessage());
    }

    @Test
    @DisplayName("CREATE (VALIDASI): Umur minus atau > 100 -> DIBLOKIR")
    void registerUser_Fail_UnrealisticAge() {
        requestDTO.setAge((byte) 105);
        Exception exception = assertThrows(RuntimeException.class, () -> userService.registerUser(requestDTO, Role.Owner));
        assertEquals("Validasi Gagal: Umur tidak valid (1-100).", exception.getMessage());
    }

    @Test
    @DisplayName("CREATE (EXPLOIT): Payload Request/Data NULL (Bomb) -> DIBLOKIR")
    void registerUser_Fail_NullPayload() {
        Exception exception = assertThrows(RuntimeException.class, () -> userService.registerUser(null, Role.Owner));
        assertEquals("Validasi Gagal: Data request tidak boleh kosong.", exception.getMessage());
    }

    // ===================================================================================
    // 2. C.R.U.D - READ (GET DATA) TESTS
    // ===================================================================================

    @Test
    @DisplayName("READ: Owner bebas melihat profil pegawai siapa saja")
    void getUserById_Success_OwnerSeesAnyone() {
        when(userRepository.findById((short) 1)).thenReturn(Optional.of(dummyUser));
        UserResponseDTO response = userService.getUserById((short) 1, Role.Owner, (short) 99);
        assertNotNull(response);
    }

    @Test
    @DisplayName("READ: Kasir sukses melihat profilnya sendiri")
    void getUserById_Success_CashierSeesSelf() {
        when(userRepository.findById((short) 1)).thenReturn(Optional.of(dummyUser));
        UserResponseDTO response = userService.getUserById((short) 1, Role.Cashier, (short) 1);
        assertNotNull(response);
    }

    @Test
    @DisplayName("READ (EXPLOIT): Kasir mengintip data profil pegawai lain -> DIBLOKIR")
    void getUserById_Fail_CashierPeeksOtherUser() {
        Exception exception = assertThrows(RuntimeException.class, () -> userService.getUserById((short) 2, Role.Cashier, (short) 1));
        assertEquals("Akses Ditolak: Anda hanya diizinkan melihat data profil sendiri.", exception.getMessage());
    }

    @Test
    @DisplayName("READ (EXPLOIT): Kasir mencoba menarik list SEMUA pegawai -> DIBLOKIR")
    void getAllUsers_Fail_CashierTriesToGetAll() {
        Exception exception = assertThrows(RuntimeException.class, () -> userService.getAllUsers(Role.Cashier));
        assertEquals("Akses Ditolak: Hanya Owner yang berhak melihat keseluruhan daftar pegawai.", exception.getMessage());
    }

    // ===================================================================================
    // 3. C.R.U.D - UPDATE TESTS
    // ===================================================================================

    @Test
    @DisplayName("UPDATE: Owner sukses mengubah data pegawai lain")
    void updateUser_Success_OwnerEditsAnyone() {
        when(userRepository.findById((short) 1)).thenReturn(Optional.of(dummyUser));
        when(userRepository.save(any(User.class))).thenAnswer(i -> i.getArgument(0));

        requestDTO.setName("Gudang Baru");
        UserResponseDTO response = userService.updateUser((short) 1, requestDTO, Role.Owner, (short) 99);
        assertNotNull(response);
    }

    @Test
    @DisplayName("UPDATE: Kasir sukses mengubah namanya sendiri")
    void updateUser_Success_CashierEditsSelf() {
        when(userRepository.findById((short) 1)).thenReturn(Optional.of(dummyUser));
        when(userRepository.save(any(User.class))).thenAnswer(i -> i.getArgument(0));

        requestDTO.setName("Kasir Update");
        UserResponseDTO response = userService.updateUser((short) 1, requestDTO, Role.Cashier, (short) 1);
        assertNotNull(response);
    }

    @Test
    @DisplayName("UPDATE (EXPLOIT): Kasir mengedit data pegawai lain -> DIBLOKIR")
    void updateUser_Fail_CashierEditsOther() {
        when(userRepository.findById((short) 2)).thenReturn(Optional.of(new User()));
        Exception exception = assertThrows(RuntimeException.class, () -> userService.updateUser((short) 2, requestDTO, Role.Cashier, (short) 1));
        assertEquals("Akses Ditolak: Anda tidak memiliki izin untuk mengubah data pengguna lain.", exception.getMessage());
    }

    @Test
    @DisplayName("UPDATE (EXPLOIT): Kasir menaikkan jabatannya sendiri jadi Owner -> DIBLOKIR")
    void updateUser_Fail_CashierUpgradesRole() {
        when(userRepository.findById((short) 1)).thenReturn(Optional.of(dummyUser));
        requestDTO.setRole(Role.Owner); // Usaha eksploitasi
        Exception exception = assertThrows(RuntimeException.class, () -> userService.updateUser((short) 1, requestDTO, Role.Cashier, (short) 1));
        assertEquals("Pelanggaran Keamanan: Pegawai tidak dapat mengubah hak akses jabatannya sendiri.", exception.getMessage());
    }

    @Test
    @DisplayName("UPDATE (EXPLOIT): Kasir mengubah emailnya sendiri (Fraud evasion) -> DIBLOKIR")
    void updateUser_Fail_CashierChangesEmail() {
        when(userRepository.findById((short) 1)).thenReturn(Optional.of(dummyUser));
        requestDTO.setEmail("hacker@email.com"); // Usaha ubah email
        Exception exception = assertThrows(RuntimeException.class, () -> userService.updateUser((short) 1, requestDTO, Role.Cashier, (short) 1));
        assertEquals("Pelanggaran Keamanan: Pegawai tidak diizinkan mengubah alamat email akun.", exception.getMessage());
    }

    // ===================================================================================
    // 4. C.R.U.D - DELETE TESTS (TOMBOL NUKLIR)
    // ===================================================================================

    @Test
    @DisplayName("DELETE: Owner sukses menghapus akun pegawai")
    void deleteUser_Success_ByOwner() {
        when(userRepository.findById((short) 1)).thenReturn(Optional.of(dummyUser));
        doNothing().when(userRepository).delete(any(User.class));

        assertDoesNotThrow(() -> userService.deleteUser((short) 1, Role.Owner));
        verify(userRepository, times(1)).delete(any(User.class));
    }

    @Test
    @DisplayName("DELETE (EXPLOIT): Kasir mencoba menghapus akun pegawai/dirinya sendiri -> DIBLOKIR")
    void deleteUser_Fail_ByCashier() {
        Exception exception = assertThrows(RuntimeException.class, () -> userService.deleteUser((short) 1, Role.Cashier));
        assertEquals("Akses Ditolak Mutlak: Hanya Owner yang memiliki otoritas untuk menghapus akun.", exception.getMessage());
        verify(userRepository, never()).delete(any(User.class));
    }
}