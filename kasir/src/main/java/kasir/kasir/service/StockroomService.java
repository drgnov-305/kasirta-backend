package kasir.kasir.service;

import kasir.kasir.dto.stockroom.StockroomRequestDTO;
import kasir.kasir.dto.stockroom.StockroomResponseDTO;
import kasir.kasir.Entities.User.Role;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class StockroomService {
    public StockroomResponseDTO recordStock(StockroomRequestDTO request, short requesterId, Role requesterRole) { return null; }
    public StockroomResponseDTO getStockById(int stockId, Role requesterRole) { return null; }
    public List<StockroomResponseDTO> getAllStocks(Role requesterRole) { return null; }
    public StockroomResponseDTO updateStock(int stockId, StockroomRequestDTO request, Role requesterRole) { return null; }
    public void deleteStock(int stockId, Role requesterRole) {}
}