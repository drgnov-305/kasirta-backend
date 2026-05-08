package kasir.kasir.dto.transaction;

public class TransactionResponseDTO {
    private Long transactionId;
    private double totalPrice;
    private double change; // Kembalian
    private String status; // Berhasil/Gagal

    // Getter & Setter
    public Long getTransactionId() { return transactionId; }
    public void setTransactionId(Long transactionId) { this.transactionId = transactionId; }
    public double getTotalPrice() { return totalPrice; }
    public void setTotalPrice(double totalPrice) { this.totalPrice = totalPrice; }
    public double getChange() { return change; }
    public void setChange(double change) { this.change = change; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
}