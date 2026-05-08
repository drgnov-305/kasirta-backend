package kasir.kasir.dto.user;

import java.time.LocalDateTime;
import kasir.kasir.Entities.User.Role;
import lombok.Data;

@Data
public class UserResponseDTO {

    private short userid;
    private String name;
    private byte age;
    private String email;
    private Role role;
    private LocalDateTime createdAt;
    private LocalDateTime updateAt;

}