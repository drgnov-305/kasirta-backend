package kasir.kasir.service;

import kasir.kasir.dto.transaction.TransactionRequestDTO;
import kasir.kasir.dto.transaction.TransactionResponseDTO;
import kasir.kasir.Entities.User.Role;
import org.springframework.stereotype.Service;

@Service
public class TransactionService {

    // =========================================================================
    // REPOSITORY KITA MATIKAN (COMMENT) SEMENTARA SELAMA FASE TESTING 
    // BIAR VS CODE LU GAK TERIAK WARNING KUNING "UNUSED FIELD" SIALAN ITU!
    // Nanti pas kita udah siap bikin logic aslinya, baru kita hidupkan lagi.
    // =========================================================================
    
    /*
    private final TransactionRepository transactionRepository;
    private final ItemRepository itemRepository;
    private final ShiftRepository shiftRepository;

    public TransactionService(TransactionRepository transactionRepository, ItemRepository itemRepository, ShiftRepository shiftRepository) {
        this.transactionRepository = transactionRepository;
        this.itemRepository = itemRepository;
        this.shiftRepository = shiftRepository;
    }
    */

    // =========================================================================
    // CANGKANG KOSONG - MESIN KASIR CHECKOUT (MURNI UNTUK MANCING ERROR TEST)
    // =========================================================================
    public TransactionResponseDTO processCheckout(TransactionRequestDTO request, Role requesterRole, short cashierId) {
        return null; // TETAP KOSONG! BIARKAN TESTNYA GAGAL DAN BERDARAH-DARAH!
    }

}