package kasir.kasir.service;

import kasir.kasir.dto.user.UserRequestDTO;
import kasir.kasir.dto.user.UserResponseDTO;
import kasir.kasir.Entities.User.Role;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class UserService {

    // C.R.U.D - CREATE
    public UserResponseDTO registerUser(UserRequestDTO request, Role requesterRole) {
        return null; // CANGKANG TERTUTUP
    }

    // C.R.U.D - READ (GET SPECIFIC)
    public UserResponseDTO getUserById(short targetUserId, Role requesterRole, short requesterId) {
        return null; // CANGKANG TERTUTUP
    }

    // C.R.U.D - READ (GET ALL)
    public List<UserResponseDTO> getAllUsers(Role requesterRole) {
        return null; // CANGKANG TERTUTUP
    }

    // C.R.U.D - UPDATE
    public UserResponseDTO updateUser(short targetUserId, UserRequestDTO request, Role requesterRole, short requesterId) {
        return null; // CANGKANG TERTUTUP
    }

    // C.R.U.D - DELETE
    public void deleteUser(short targetUserId, Role requesterRole) {
        // CANGKANG TERTUTUP (Void tidak return apa-apa)
    }
}