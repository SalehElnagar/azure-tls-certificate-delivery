"""Synthetic, dependency-free responses identify the selected application route."""
import os


def app(environ, start_response):
    body = ('TLS renewal lab application: ' + os.environ.get('LAB_APP_NAME', 'local') + '\n').encode()
    start_response('200 OK', [('Content-Type', 'text/plain; charset=utf-8'), ('Content-Length', str(len(body)))])
    return [body]
