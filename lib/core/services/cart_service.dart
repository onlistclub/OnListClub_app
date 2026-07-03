/// Singleton che tiene in memoria l'ultimo ordine composto dall'utente
/// (ticket o tavolo), così la `CartScreen` può ri-mostrarlo quando si torna
/// al carrello dalla bottom nav (dove non arrivano più gli `arguments` di
/// navigazione). Viene svuotato dopo un ordine completato con successo.
class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  Map<String, dynamic>? current;

  void clear() {
    current = null;
  }
}
