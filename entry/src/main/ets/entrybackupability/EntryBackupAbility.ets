import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

const DOMAIN = 0x0000;
const TAG = 'A1a1';

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    hilog.info(DOMAIN, TAG, '[EntryBackupAbility] onBackup ok');
    await Promise.resolve();
  }

  async onRestore(bundleVersion: BundleVersion) {
    hilog.info(DOMAIN, TAG, '[EntryBackupAbility] onRestore ok %{public}s', JSON.stringify(bundleVersion));
    await Promise.resolve();
  }
}
