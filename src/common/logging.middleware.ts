import { Injectable, Logger, NestMiddleware } from '@nestjs/common';
import { NextFunction, Request, Response } from 'express';

/**
 * Logs every HTTP request and its response.
 *
 *   → POST /api/orders req={"kitchenId":"…","items":[…]}
 *   ← POST /api/orders 201 42ms res={"id":"…","status":"received",…}
 *
 * Bodies are JSON-stringified and truncated. Multipart uploads are not dumped
 * (they're binary). Runs as middleware so it also sees requests rejected by the
 * auth guard (401s), which an interceptor would miss.
 */
@Injectable()
export class LoggingMiddleware implements NestMiddleware {
  private readonly logger = new Logger('HTTP');

  use(req: Request, res: Response, next: NextFunction): void {
    const start = Date.now();
    const { method, originalUrl } = req;
    const contentType = req.headers['content-type'] ?? '';

    const reqBody = contentType.includes('multipart/form-data')
      ? '[multipart]'
      : this.trim(req.body);
    this.logger.log(`→ ${method} ${originalUrl}${reqBody ? ` req=${reqBody}` : ''}`);

    // Capture the response body by wrapping res.json (Nest sends JSON this way).
    let respBody: unknown;
    const originalJson = res.json.bind(res);
    res.json = (body: unknown) => {
      respBody = body;
      return originalJson(body);
    };

    res.on('finish', () => {
      const ms = Date.now() - start;
      const line =
        `← ${method} ${originalUrl} ${res.statusCode} ${ms}ms` +
        (respBody !== undefined ? ` res=${this.trim(respBody)}` : '');
      if (res.statusCode >= 500) this.logger.error(line);
      else if (res.statusCode >= 400) this.logger.warn(line);
      else this.logger.log(line);
    });

    next();
  }

  /** JSON-stringify and cap length so logs stay readable. */
  private trim(obj: unknown): string {
    if (obj === undefined || obj === null) return '';
    try {
      const s = typeof obj === 'string' ? obj : JSON.stringify(obj);
      if (!s || s === '{}') return '';
      return s.length > 800 ? `${s.slice(0, 800)}…(truncated)` : s;
    } catch {
      return '[unserializable]';
    }
  }
}
