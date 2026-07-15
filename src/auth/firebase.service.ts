import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  App,
  cert,
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
      const clientEmail = this.config.get<string>('FIREBASE_CLIENT_EMAIL');
      const privateKey = this.config.get<string>('FIREBASE_PRIVATE_KEY');

      if (clientEmail && privateKey) {
        // Use individual env vars from .env
        app = initializeApp({
          credential: cert({
            projectId,
            clientEmail,
            privateKey: privateKey.replace(/\\n/g, '\n'),
          }),
        });
      } else {
        // Fall back to GOOGLE_APPLICATION_CREDENTIALS JSON file
        app = initializeApp({
          credential: applicationDefault(),
          projectId,
        });
      }
    }

    this.auth = getAuth(app);
  }

  /** Verify a Firebase ID token and return the decoded claims. */
  async verifyIdToken(idToken: string): Promise<DecodedIdToken> {
    return this.auth.verifyIdToken(idToken);
  }
}
