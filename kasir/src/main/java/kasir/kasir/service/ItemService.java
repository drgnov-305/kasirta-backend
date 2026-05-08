package kasir.kasir.service;

import kasir.kasir.dto.item.ItemRequestDTO;
import kasir.kasir.dto.item.ItemResponseDTO;
import kasir.kasir.Entities.User.Role;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class ItemService {
    public ItemResponseDTO createItem(ItemRequestDTO request, Role requesterRole) { return null; }
    public ItemResponseDTO getItemById(int itemId, Role requesterRole) { return null; }
    public List<ItemResponseDTO> getAllItems(Role requesterRole) { return null; }
    public ItemResponseDTO updateItem(int itemId, ItemRequestDTO request, Role requesterRole) { return null; }
    public void deleteItem(int itemId, Role requesterRole) {}
}