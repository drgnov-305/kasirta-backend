package kasir.kasir.dto.transaction;

public class TransactionRequestDTO {
    private int itemId;
    private int quantity;
    private String paymentMethod;
    private double amountPaid;
    private byte shiftId; // Shift yang lagi aktif

    // Getter & Setter
    public int getItemId() { return itemId; }
    public void setItemId(int itemId) { this.itemId = itemId; }
    public int getQuantity() { return quantity; }
    public void setQuantity(int quantity) { this.quantity = quantity; }
    public String getPaymentMethod() { return paymentMethod; }
    public void setPaymentMethod(String paymentMethod) { this.paymentMethod = paymentMethod; }
    public double getAmountPaid() { return amountPaid; }
    public void setAmountPaid(double amountPaid) { this.amountPaid = amountPaid; }
    public byte getShiftId() { return shiftId; }
    public void setShiftId(byte shiftId) { this.shiftId = shiftId; }
}