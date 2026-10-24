import 'package:flutter_test/flutter_test.dart';
import 'package:alone_vpn/core/settings.dart';
import 'package:alone_vpn/core/storage.dart';
import 'package:alone_vpn/data/stores.dart';

const _ss = 'ss://YWVzLTI1Ni1nY206cGFzcw==@1.2.3.4:8388#Alive';
const _hy = 'hysteria2://secret@5.6.7.8:443#Udp';
const _dead1 = 'ss://YWVzLTI1Ni1nY206cGFzcw==@9.9.9.9:8388#Dead1';
const _dead2 = 'trojan://pw@8.8.4.4:443#Dead2';

void main() {
  Future<void> prep(List<String> links) async {
    AppSettings.storage = MemoryStorage({'al.onboarded': true, 'al.links': links});
    AppSettings.I.onboarded = false;
    await AppSettings.I.load();
    ServerStore.I.lat.clear();
    ServerStore.I.load();
  }

  test('UDP-based servers are never judged by a TCP test', () async {
    await prep([_ss, _hy]);
    expect(ServerStore.I.testable.map((s) => s.title), ['Alive']);
  });

  test('dead servers = no answer or negative; untested and UDP ones are kept', () async {
    await prep([_ss, _hy, _dead1, _dead2]);
    final s = ServerStore.I;
    s.lat[s.items[0].id] = 42; // alive
    s.lat[s.items[2].id] = null; // no answer
    s.lat[s.items[3].id] = -1; // negative
    final dead = s.deadServers().map((e) => e.title).toSet();
    expect(dead, {'Dead1', 'Dead2'});
  });

  test('removeMany deletes them from the list, the saved links and the active choice', () async {
    await prep([_ss, _dead1, _dead2]);
    final s = ServerStore.I;
    s.setActive(s.items[1].id);
    s.removeMany([s.items[1], s.items[2]]);
    expect(s.items.map((e) => e.title), ['Alive']);
    expect(AppSettings.I.serverLinks, [_ss]);
    expect(AppSettings.I.activeServer, s.items.first.id);
  });

  test('subscriptions are remembered and survive a reload', () async {
    await prep([_ss]);
    AppSettings.I.update(() => AppSettings.I.subs = [
          {'url': 'https://example.com/sub', 'name': 'example.com', 'at': 1, 'links': [_ss]}
        ]);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    AppSettings.I.subs = [];
    await AppSettings.I.load();
    expect(AppSettings.I.subs.length, 1);
    expect(AppSettings.I.subs.first['url'], 'https://example.com/sub');
    ServerStore.I.removeSub('https://example.com/sub');
    expect(AppSettings.I.subs, isEmpty);
  });
}
