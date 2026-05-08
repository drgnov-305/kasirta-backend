package kasir.kasir.service;

import kasir.kasir.dto.shift.ShiftRequestDTO;
import kasir.kasir.dto.shift.ShiftResponseDTO;
import kasir.kasir.Entities.User.Role;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class ShiftService {
    public ShiftResponseDTO openShift(ShiftRequestDTO request, short requesterId, Role requesterRole) { return null; }
    public ShiftResponseDTO getShiftById(byte shiftId, short requesterId, Role requesterRole) { return null; }
    public List<ShiftResponseDTO> getAllShifts(Role requesterRole) { return null; }
    public ShiftResponseDTO updateShift(byte shiftId, ShiftRequestDTO request, short requesterId, Role requesterRole) { return null; }
    public void deleteShift(byte shiftId, Role requesterRole) {}
}