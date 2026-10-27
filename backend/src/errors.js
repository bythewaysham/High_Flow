export class HttpError extends Error {
  constructor(status, message, code = 'request_failed') {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export function asyncRoute(handler) {
  return (request, response, next) => {
    Promise.resolve(handler(request, response, next)).catch(next);
  };
}

export function errorHandler(error, _request, response, _next) {
  if (error instanceof HttpError) {
    return response.status(error.status).json({
      error: { code: error.code, message: error.message },
    });
  }

  if (error?.name === 'ZodError') {
    return response.status(400).json({
      error: {
        code: 'invalid_request',
        message: 'Request data is invalid.',
        details: error.issues.map((issue) => ({
          path: issue.path.join('.'),
          message: issue.message,
        })),
      },
    });
  }

  if (error?.code === '23505') {
    return response.status(409).json({
      error: { code: 'already_exists', message: 'That record already exists.' },
    });
  }

  if (error?.code === '23503') {
    return response.status(400).json({
      error: {
        code: 'unknown_reference',
        message: 'A referenced robot, order, or product does not exist.',
      },
    });
  }

  if (error?.type === 'entity.too.large') {
    return response.status(413).json({
      error: { code: 'payload_too_large', message: 'Request body is too large.' },
    });
  }

  console.error('Unhandled API error:', error);
  return response.status(500).json({
    error: { code: 'internal_error', message: 'The request could not be completed.' },
  });
}
