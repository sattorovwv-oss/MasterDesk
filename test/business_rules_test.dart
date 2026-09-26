import 'package:flutter_test/flutter_test.dart';

void main() {
  test('order balance follows total minus net paid', () {
    const work = 12000;
    const part = 18000;
    const discount = 3000;
    const deposit = 10000;
    final total = work + part - discount;
    final balance = total - deposit;
    expect(total, 27000);
    expect(balance, 17000);
  });

  test('FIFO example cost is deterministic', () {
    final batches = <({int quantity, int unitCost})>[
      (quantity: 1, unitCost: 10000),
      (quantity: 2, unitCost: 12000),
    ];
    var requested = 2;
    var cost = 0;
    for (final batch in batches) {
      final consumed = requested < batch.quantity ? requested : batch.quantity;
      cost += consumed * batch.unitCost;
      requested -= consumed;
      if (requested == 0) break;
    }
    expect(cost, 22000);
  });
}
