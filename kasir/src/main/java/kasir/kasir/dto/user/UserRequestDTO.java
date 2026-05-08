package kasir.kasir.dto.user;

import kasir.kasir.Entities.User.Role;
import lombok.Data;

@Data
public class UserRequestDTO {
    
    private String name;
    private byte age;
    private String email;
    private String password; 
    private Role role;

}