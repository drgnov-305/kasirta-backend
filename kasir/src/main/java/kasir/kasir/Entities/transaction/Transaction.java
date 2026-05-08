package kasir.kasir.Entities.transaction;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "transactions")
public class Transaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long transactionId; // ID Struk

    @Column(nullable = false)
    private short cashierId; // Siapa kasirnya

    @Column(nullable = false)
    private byte shiftId; // Masuk ke sesi shift yang mana

    @Column(nullable = false)
    private int itemId; // Barang apa yang dibeli

    @Column(nullable = false)
    private int quantity; // Beli berapa biji

    @Column(nullable = false)
    private double totalPrice; // Total Harga Belanja

    @Column(nullable = false)
    private String paymentMethod; // Cash, QRIS, E-Wallet

    @Column(nullable = false)
    private double amountPaid; // Uang yang dikasih pelanggan

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    // Getter dan Setter
    public Long getTransactionId() { return transactionId; }
    public void setTransactionId(Long transactionId) { this.transactionId = transactionId; }
    public short getCashierId() { return cashierId; }
    public void setCashierId(short cashierId) { this.cashierId = cashierId; }
    public byte getShiftId() { return shiftId; }
    public void setShiftId(byte shiftId) { this.shiftId = shiftId; }
    public int getItemId() { return itemId; }
    public void setItemId(int itemId) { this.itemId = itemId; }
    public int getQuantity() { return quantity; }
    public void setQuantity(int quantity) { this.quantity = quantity; }
    public double getTotalPrice() { return totalPrice; }
    public void setTotalPrice(double totalPrice) { this.totalPrice = totalPrice; }
    public String getPaymentMethod() { return paymentMethod; }
    public void setPaymentMethod(String paymentMethod) { this.paymentMethod = paymentMethod; }
    public double getAmountPaid() { return amountPaid; }
    public void setAmountPaid(double amountPaid) { this.amountPaid = amountPaid; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}