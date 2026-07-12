import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  App,
  getApps,
  initializeApp,
  applicationDefault,
} from 'firebase-admin/app';
import { Auth, DecodedIdToken, getAuth } from 'firebase-admin/auth';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private auth: Auth;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    let app: App;

    if (getApps().length) {
      app = getApps()[0]!;
    } else {
      const projectId = this.config.get<string>('FIREBASE_PROJECT_ID');

      // In production, set GOOGLE_APPLICATION_CREDENTIALS env var pointing
      // to the service-account JSON. Locally, projectId alone works with
      // the Firebase emulator.
      app = initializeApp({
        credential: applicationDefault(),
        projectId,
      });
    }

    this.auth = getAuth(app);
  }

  /** Verify a Firebase ID token and return the decoded claims. */
  async verifyIdToken(idToken: string): Promise<DecodedIdToken> {
    return this.auth.verifyIdToken(idToken);
  }
}
