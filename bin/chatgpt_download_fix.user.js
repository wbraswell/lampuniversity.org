// ==UserScript==
// @name         ChatGPT Download Fix
// @namespace    local.wbraswell.chatgpt
// @version      0.008
// @description  Fix ChatGPT file downloads stuck on 'Starting download'.
// @match        https://chatgpt.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

(function () {
    'use strict';

    const CFG = {
        eventName: '__chatgpt_download_fix_bridge_v008__',
        scriptId: 'chatgpt-download-fix-bridge-v008',
        stateKey: 'chatgpt_download_fix_state_v0_008',
        toastHostId: 'chatgpt-download-fix-toast-host-v008',
        candidateWaitMs: 5000,
        nativeFollowupWaitMs: 900,
        toastMs: 5000,
        requestTtlMs: 20000,
        candidateTtlMs: 20000,
        debugEnabled: true,
        debugLevel: 'info'
    };

    const LOG_LEVELS = {
        error: 0,
        warn: 1,
        info: 2,
        debug: 3
    };

    const runtime = {
        requestLog: [],
        candidates: [],
        candidateWaiters: [],
        nextJobId: 1,
        nextCandidateId: 1,
        debugSeq: 1
    };

    function shouldLog(level) {
        if (!CFG.debugEnabled) {
            return false;
        }

        const requested = Object.prototype.hasOwnProperty.call(LOG_LEVELS, level) ? LOG_LEVELS[level] : LOG_LEVELS.debug;
        const threshold = Object.prototype.hasOwnProperty.call(LOG_LEVELS, CFG.debugLevel) ? LOG_LEVELS[CFG.debugLevel] : LOG_LEVELS.info;
        return requested <= threshold;
    }

    function debugLog(level, message, detail) {
        if (!shouldLog(level)) {
            return;
        }

        const seq = runtime.debugSeq++;
        const prefix = '[ChatGPT Download Fix v0.008 #' + seq + '] ' + message;

        if (level === 'error') {
            if (detail !== undefined) {
                console.error(prefix, detail);
            }
            else {
                console.error(prefix);
            }
            return;
        }

        if (level === 'warn') {
            if (detail !== undefined) {
                console.warn(prefix, detail);
            }
            else {
                console.warn(prefix);
            }
            return;
        }

        if (level === 'info') {
            if (detail !== undefined) {
                console.info(prefix, detail);
            }
            else {
                console.info(prefix);
            }
            return;
        }

        if (detail !== undefined) {
            console.log(prefix, detail);
        }
        else {
            console.log(prefix);
        }
    }

    function nowMs() {
        return Date.now();
    }

    function waitMs(delayMs) {
        return new Promise(function (resolve) {
            setTimeout(resolve, delayMs);
        });
    }

    function normalizeUrl(input) {
        try {
            return new URL(String(input || ''), location.href).toString();
        }
        catch (error) {
            return String(input || '');
        }
    }

    function sanitizeFilename(name) {
        const cleaned = String(name || '').replace(/[\\/\0]/g, '_').trim();
        return cleaned || 'download.bin';
    }

    function trimFilename(name) {
        return String(name || '').trim();
    }

    function isInterpreterDownloadUrl(url) {
        const normalized = normalizeUrl(url);
        return normalized.indexOf(location.origin + '/backend-api/conversation/') === 0 && normalized.indexOf('/interpreter/download') !== -1;
    }

    function isEstuaryContentUrl(url) {
        const normalized = normalizeUrl(url);
        return normalized.indexOf(location.origin + '/backend-api/estuary/content') === 0;
    }

    function shouldTrackRequest(url, source) {
        const normalized = normalizeUrl(url);

        if (!/^https?:\/\//i.test(normalized)) {
            return false;
        }

        if (source && String(source).indexOf('fallback.') === 0) {
            return true;
        }

        if (isInterpreterDownloadUrl(normalized)) {
            return true;
        }

        if (isEstuaryContentUrl(normalized)) {
            return true;
        }

        return false;
    }

    function defaultState() {
        return {
            status: 'unknown',
            nativeStatus: 'unknown',
            workaroundStatus: 'unknown',
            lastMessage: '',
            lastBrokenAt: 0,
            lastHealthyAt: 0,
            lastWorkedAroundAt: 0
        };
    }

    function readState() {
        try {
            const raw = localStorage.getItem(CFG.stateKey);
            const parsed = raw ? JSON.parse(raw) : defaultState();
            return Object.assign(defaultState(), parsed);
        }
        catch (error) {
            debugLog('warn', 'readState failed, using fallback', {
                error: String(error && error.message ? error.message : error)
            });
            return defaultState();
        }
    }

    function writeState(patch) {
        const previous = readState();
        const next = Object.assign({}, previous, patch);
        localStorage.setItem(CFG.stateKey, JSON.stringify(next));
        debugLog('info', 'writeState', {
            previous: previous,
            patch: patch,
            next: next
        });
        return next;
    }

    function showToast(title, body) {
        debugLog('info', 'showToast requested', {
            title: title,
            body: body
        });

        let host = document.getElementById(CFG.toastHostId);

        if (!host) {
            const style = document.createElement('style');
            style.textContent =
                '#' + CFG.toastHostId + '{position:fixed;right:16px;bottom:16px;z-index:2147483647;display:flex;flex-direction:column;gap:8px;pointer-events:none}' +
                '#' + CFG.toastHostId + ' .toast{max-width:420px;padding:10px 12px;border-radius:10px;background:rgba(24,24,27,.96);color:#fff;font:13px/1.45 sans-serif;box-shadow:0 12px 30px rgba(0,0,0,.35)}' +
                '#' + CFG.toastHostId + ' .title{font-weight:700;margin-bottom:2px}';
            document.documentElement.appendChild(style);

            host = document.createElement('div');
            host.id = CFG.toastHostId;
            document.documentElement.appendChild(host);
        }

        const box = document.createElement('div');
        box.className = 'toast';
        box.innerHTML = '<div class="title"></div><div class="body"></div>';
        box.querySelector('.title').textContent = title;
        box.querySelector('.body').textContent = body;
        host.appendChild(box);

        setTimeout(function () {
            box.remove();
        }, CFG.toastMs);
    }

    function pruneRequests() {
        const cutoff = nowMs() - CFG.requestTtlMs;
        runtime.requestLog = runtime.requestLog.filter(function (entry) {
            return entry.observedAt >= cutoff;
        });
    }

    function recordRequest(url, source) {
        const normalized = normalizeUrl(url);

        if (!shouldTrackRequest(normalized, source)) {
            return;
        }

        pruneRequests();

        const entry = {
            url: normalized,
            source: source || 'unknown',
            observedAt: nowMs()
        };

        runtime.requestLog.push(entry);

        debugLog('info', 'recordRequest stored', {
            entry: entry,
            requestLogLength: runtime.requestLog.length
        });
    }

    function wasRequestObservedSince(url, startedAt) {
        const normalized = normalizeUrl(url);
        pruneRequests();

        const matches = runtime.requestLog.filter(function (entry) {
            return entry.observedAt >= startedAt && entry.url === normalized;
        });

        const found = matches.length > 0;

        debugLog('info', 'wasRequestObservedSince', {
            url: normalized,
            startedAt: startedAt,
            found: found,
            matchingEntries: matches
        });

        return found;
    }

    function pruneCandidates() {
        const cutoff = nowMs() - CFG.candidateTtlMs;
        runtime.candidates = runtime.candidates.filter(function (entry) {
            return entry.observedAt >= cutoff;
        });
    }

    function removeCandidateWaiter(waiterId) {
        runtime.candidateWaiters = runtime.candidateWaiters.filter(function (waiter) {
            return waiter.id !== waiterId;
        });
    }

    function notifyCandidateWaiters(candidate) {
        const snapshot = runtime.candidateWaiters.slice();

        for (const waiter of snapshot) {
            if (candidate.observedAt >= waiter.floor) {
                debugLog('info', 'notifyCandidateWaiters resolving waiter', {
                    waiterId: waiter.id,
                    candidate: candidate
                });
                waiter.resolve(candidate);
            }
        }
    }

    function enqueueCandidate(downloadUrl, requestUrl, fileName, source) {
        const normalized = normalizeUrl(downloadUrl);

        if (!/^https?:\/\//i.test(normalized)) {
            debugLog('warn', 'enqueueCandidate ignored non-http downloadUrl', {
                downloadUrl: downloadUrl,
                requestUrl: requestUrl,
                fileName: fileName,
                source: source
            });
            return null;
        }

        pruneCandidates();

        const candidate = {
            id: runtime.nextCandidateId++,
            observedAt: nowMs(),
            used: false,
            downloadUrl: normalized,
            requestUrl: normalizeUrl(requestUrl || ''),
            fileName: trimFilename(fileName || ''),
            source: source || 'unknown'
        };

        runtime.candidates.push(candidate);

        debugLog('info', 'enqueueCandidate stored', {
            candidate: candidate,
            candidatesLength: runtime.candidates.length
        });

        notifyCandidateWaiters(candidate);
        return candidate;
    }

    function pickBestCandidate(startedAt) {
        pruneCandidates();

        const floor = startedAt - 1500;
        let best = null;

        for (const candidate of runtime.candidates) {
            if (candidate.used) {
                continue;
            }

            if (candidate.observedAt < floor) {
                continue;
            }

            if (!best) {
                best = candidate;
                continue;
            }

            const candidateIsMetadata = isInterpreterDownloadUrl(candidate.requestUrl);
            const bestIsMetadata = isInterpreterDownloadUrl(best.requestUrl);

            if (candidateIsMetadata && !bestIsMetadata) {
                best = candidate;
                continue;
            }

            if (candidate.observedAt > best.observedAt) {
                best = candidate;
            }
        }

        debugLog('info', 'pickBestCandidate result', {
            startedAt: startedAt,
            best: best
        });

        return best;
    }

    function waitForCandidate(startedAt, timeoutMs) {
        const immediate = pickBestCandidate(startedAt);

        if (immediate) {
            debugLog('info', 'waitForCandidate resolved immediately', {
                startedAt: startedAt,
                candidate: immediate
            });
            return Promise.resolve(immediate);
        }

        return new Promise(function (resolve) {
            const waiterId = 'waiter-' + String(nowMs()) + '-' + String(Math.random()).slice(2);
            let settled = false;

            function finalize(candidate) {
                if (settled) {
                    return;
                }

                settled = true;
                removeCandidateWaiter(waiterId);
                resolve(candidate || pickBestCandidate(startedAt) || null);
            }

            const timerId = setTimeout(function () {
                debugLog('warn', 'waitForCandidate timed out', {
                    startedAt: startedAt,
                    timeoutMs: timeoutMs
                });
                finalize(null);
            }, timeoutMs);

            runtime.candidateWaiters.push({
                id: waiterId,
                floor: startedAt - 1500,
                resolve: function (candidate) {
                    clearTimeout(timerId);
                    finalize(candidate);
                }
            });

            debugLog('info', 'waitForCandidate registered waiter', {
                waiterId: waiterId,
                startedAt: startedAt,
                timeoutMs: timeoutMs
            });

            const afterRegister = pickBestCandidate(startedAt);

            if (afterRegister) {
                clearTimeout(timerId);
                finalize(afterRegister);
            }
        });
    }

    function parseContentDisposition(headerValue) {
        if (!headerValue) {
            return null;
        }

        let match = headerValue.match(/filename\*=UTF-8''([^;]+)/i);
        if (match && match[1]) {
            try {
                return decodeURIComponent(match[1]);
            }
            catch (error) {
                return match[1];
            }
        }

        match = headerValue.match(/filename="([^"]+)"/i);
        if (match && match[1]) {
            return match[1];
        }

        match = headerValue.match(/filename=([^;]+)/i);
        if (match && match[1]) {
            return match[1].trim();
        }

        return null;
    }

    function isVisibleElement(node) {
        if (!(node instanceof Element)) {
            return false;
        }

        const style = getComputedStyle(node);

        if (style.display === 'none' || style.visibility === 'hidden') {
            return false;
        }

        const rect = node.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
    }

    function visibleTextExists(text) {
        const root = document.body || document.documentElement;
        const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT);
        let node = walker.nextNode();

        while (node) {
            if (node.textContent && node.textContent.indexOf(text) !== -1 && isVisibleElement(node)) {
                debugLog('info', 'visibleTextExists matched', {
                    text: text,
                    textContent: node.textContent
                });
                return true;
            }
            node = walker.nextNode();
        }

        return false;
    }

    function pageBridgeMain(config) {
        'use strict';

        const BRIDGE_PREFIX = '[ChatGPT Download Fix Bridge v0.008]';
        const LOG_LEVELS_LOCAL = {
            error: 0,
            warn: 1,
            info: 2,
            debug: 3
        };

        function bridgeShouldLog(level) {
            if (!config.debugEnabled) {
                return false;
            }

            const requested = Object.prototype.hasOwnProperty.call(LOG_LEVELS_LOCAL, level) ? LOG_LEVELS_LOCAL[level] : LOG_LEVELS_LOCAL.debug;
            const threshold = Object.prototype.hasOwnProperty.call(LOG_LEVELS_LOCAL, config.debugLevel) ? LOG_LEVELS_LOCAL[config.debugLevel] : LOG_LEVELS_LOCAL.info;
            return requested <= threshold;
        }

        function bridgeLog(level, message, detail) {
            if (!bridgeShouldLog(level)) {
                return;
            }

            const prefix = BRIDGE_PREFIX + ' ' + message;

            if (level === 'error') {
                if (detail !== undefined) {
                    console.error(prefix, detail);
                }
                else {
                    console.error(prefix);
                }
                return;
            }

            if (level === 'warn') {
                if (detail !== undefined) {
                    console.warn(prefix, detail);
                }
                else {
                    console.warn(prefix);
                }
                return;
            }

            if (level === 'info') {
                if (detail !== undefined) {
                    console.info(prefix, detail);
                }
                else {
                    console.info(prefix);
                }
                return;
            }

            if (detail !== undefined) {
                console.log(prefix, detail);
            }
            else {
                console.log(prefix);
            }
        }

        function normalizeBridgeUrl(input) {
            try {
                return new URL(String(input || ''), location.href).toString();
            }
            catch (error) {
                return String(input || '');
            }
        }

        function isInterpreterDownloadBridgeUrl(url) {
            const normalized = normalizeBridgeUrl(url);
            return normalized.indexOf(location.origin + '/backend-api/conversation/') === 0 && normalized.indexOf('/interpreter/download') !== -1;
        }

        function isEstuaryContentBridgeUrl(url) {
            const normalized = normalizeBridgeUrl(url);
            return normalized.indexOf(location.origin + '/backend-api/estuary/content') === 0;
        }

        function shouldTrackBridgeRequest(url, source) {
            const normalized = normalizeBridgeUrl(url);

            if (!/^https?:\/\//i.test(normalized)) {
                return false;
            }

            if (source && String(source).indexOf('fallback.') === 0) {
                return true;
            }

            if (isInterpreterDownloadBridgeUrl(normalized)) {
                return true;
            }

            if (isEstuaryContentBridgeUrl(normalized)) {
                return true;
            }

            return false;
        }

        if (window.__chatgptDownloadFixBridgeV008Installed) {
            bridgeLog('warn', 'bridge already installed');
            return;
        }

        window.__chatgptDownloadFixBridgeV008Installed = true;
        bridgeLog('info', 'installing bridge', {
            eventName: config.eventName
        });

        function emit(detail) {
            try {
                window.dispatchEvent(new CustomEvent(config.eventName, {
                    detail: detail
                }));
            }
            catch (error) {
                bridgeLog('error', 'emit failed', {
                    error: String(error && error.message ? error.message : error),
                    detail: detail
                });
            }
        }

        function emitRequest(url, source) {
            const normalized = normalizeBridgeUrl(url);

            if (!shouldTrackBridgeRequest(normalized, source)) {
                return;
            }

            bridgeLog('info', 'emitRequest', {
                url: normalized,
                source: source || 'page'
            });

            emit({
                type: 'request',
                url: normalized,
                source: source || 'page'
            });
        }

        function emitCandidate(downloadUrl, requestUrl, fileName, source) {
            const normalized = normalizeBridgeUrl(downloadUrl);

            if (!/^https?:\/\//i.test(normalized)) {
                bridgeLog('warn', 'emitCandidate ignored non-http downloadUrl', {
                    downloadUrl: downloadUrl,
                    requestUrl: requestUrl,
                    fileName: fileName,
                    source: source || 'page'
                });
                return;
            }

            bridgeLog('info', 'emitCandidate', {
                downloadUrl: normalized,
                requestUrl: requestUrl,
                fileName: fileName,
                source: source || 'page'
            });

            emit({
                type: 'candidate',
                downloadUrl: normalized,
                requestUrl: normalizeBridgeUrl(requestUrl || ''),
                fileName: String(fileName || '').trim(),
                source: source || 'page'
            });
        }

        function inspectPayloadObject(node, requestUrl, source, depth) {
            if (depth > 8 || node === null || node === undefined) {
                return;
            }

            if (typeof node !== 'object') {
                return;
            }

            if (typeof node.download_url === 'string' && node.download_url) {
                emitCandidate(node.download_url, requestUrl, node.file_name || '', source);
            }

            if (Array.isArray(node)) {
                for (const item of node) {
                    inspectPayloadObject(item, requestUrl, source, depth + 1);
                }
                return;
            }

            for (const key of Object.keys(node)) {
                inspectPayloadObject(node[key], requestUrl, source, depth + 1);
            }
        }

        function inspectText(text, requestUrl, source) {
            if (!text) {
                return;
            }

            try {
                const payload = JSON.parse(text);
                inspectPayloadObject(payload, requestUrl, source, 0);
                return;
            }
            catch (error) {
                bridgeLog('debug', 'inspectText JSON parse failed, trying regex', {
                    requestUrl: requestUrl,
                    source: source,
                    error: String(error && error.message ? error.message : error)
                });
            }

            const regex = /"download_url"\s*:\s*"((?:\\.|[^"])*)"/g;
            let match = regex.exec(text);

            while (match) {
                const rawValue = match[1];
                let decoded = rawValue;

                try {
                    decoded = JSON.parse('"' + rawValue + '"');
                }
                catch (error) {
                    decoded = rawValue.replace(/\\\//g, '/').replace(/\\"/g, '"');
                }

                emitCandidate(decoded, requestUrl, '', source);
                match = regex.exec(text);
            }
        }

        if (typeof window.fetch === 'function') {
            const originalFetch = window.fetch;

            window.fetch = function () {
                const args = Array.prototype.slice.call(arguments);
                const requestUrl = normalizeBridgeUrl(args[0] && args[0].url ? args[0].url : args[0]);

                emitRequest(requestUrl, 'page.fetch');

                return originalFetch.apply(this, args).then(function (response) {
                    try {
                        const contentType = response.headers.get('content-type') || '';

                        if (requestUrl.indexOf(location.origin + '/backend-api/') === 0 && contentType.toLowerCase().indexOf('json') !== -1) {
                            response.clone().text().then(function (text) {
                                inspectText(text, requestUrl, 'page.fetch');
                            }).catch(function (error) {
                                bridgeLog('error', 'page fetch clone text failed', {
                                    requestUrl: requestUrl,
                                    error: String(error && error.message ? error.message : error)
                                });
                            });
                        }
                    }
                    catch (error) {
                        bridgeLog('error', 'page fetch response handling failed', {
                            requestUrl: requestUrl,
                            error: String(error && error.message ? error.message : error)
                        });
                    }

                    return response;
                }).catch(function (error) {
                    bridgeLog('error', 'page fetch rejected', {
                        requestUrl: requestUrl,
                        error: String(error && error.message ? error.message : error)
                    });
                    throw error;
                });
            };
        }

        if (typeof window.XMLHttpRequest === 'function') {
            const originalOpen = XMLHttpRequest.prototype.open;
            const originalSend = XMLHttpRequest.prototype.send;

            XMLHttpRequest.prototype.open = function (method, url) {
                this.__chatgptDownloadFixBridgeUrlV008 = normalizeBridgeUrl(url);
                return originalOpen.apply(this, arguments);
            };

            XMLHttpRequest.prototype.send = function () {
                emitRequest(this.__chatgptDownloadFixBridgeUrlV008 || '', 'page.xhr');

                this.addEventListener('loadend', function () {
                    try {
                        const requestUrl = this.__chatgptDownloadFixBridgeUrlV008 || '';
                        const contentType = this.getResponseHeader('content-type') || '';

                        if (requestUrl.indexOf(location.origin + '/backend-api/') !== 0 || contentType.toLowerCase().indexOf('json') === -1) {
                            return;
                        }

                        let text = '';

                        if (this.responseType === '' || this.responseType === 'text') {
                            text = this.responseText || '';
                        }
                        else if (this.responseType === 'json') {
                            text = JSON.stringify(this.response);
                        }

                        inspectText(text, requestUrl, 'page.xhr');
                    }
                    catch (error) {
                        bridgeLog('error', 'page XHR loadend handling failed', {
                            error: String(error && error.message ? error.message : error)
                        });
                    }
                });

                return originalSend.apply(this, arguments);
            };
        }

        if (typeof HTMLAnchorElement !== 'undefined' && HTMLAnchorElement.prototype && typeof HTMLAnchorElement.prototype.click === 'function') {
            const originalAnchorClick = HTMLAnchorElement.prototype.click;

            HTMLAnchorElement.prototype.click = function () {
                try {
                    if (this && this.dataset && this.dataset.chatgptDownloadFixTemp === '1') {
                        bridgeLog('debug', 'ignored synthetic temp anchor click');
                    }
                    else {
                        emitRequest(this.href || '', 'page.anchor.click');
                    }
                }
                catch (error) {
                    bridgeLog('error', 'page anchor click handling failed', {
                        error: String(error && error.message ? error.message : error)
                    });
                }

                return originalAnchorClick.apply(this, arguments);
            };
        }

        if (typeof window.open === 'function') {
            const originalWindowOpen = window.open;

            window.open = function (url) {
                try {
                    emitRequest(url || '', 'page.window.open');
                }
                catch (error) {
                    bridgeLog('error', 'page window.open handling failed', {
                        error: String(error && error.message ? error.message : error)
                    });
                }

                return originalWindowOpen.apply(this, arguments);
            };
        }

        if (typeof Location !== 'undefined' && Location.prototype) {
            if (typeof Location.prototype.assign === 'function') {
                const originalAssign = Location.prototype.assign;

                Location.prototype.assign = function (url) {
                    try {
                        emitRequest(url || '', 'page.location.assign');
                    }
                    catch (error) {
                        bridgeLog('error', 'location.assign handling failed', {
                            error: String(error && error.message ? error.message : error)
                        });
                    }

                    return originalAssign.apply(this, arguments);
                };
            }

            if (typeof Location.prototype.replace === 'function') {
                const originalReplace = Location.prototype.replace;

                Location.prototype.replace = function (url) {
                    try {
                        emitRequest(url || '', 'page.location.replace');
                    }
                    catch (error) {
                        bridgeLog('error', 'location.replace handling failed', {
                            error: String(error && error.message ? error.message : error)
                        });
                    }

                    return originalReplace.apply(this, arguments);
                };
            }
        }

        bridgeLog('info', 'bridge installed successfully');
    }

    function injectBridge() {
        if (document.getElementById(CFG.scriptId)) {
            return;
        }

        try {
            const script = document.createElement('script');
            script.id = CFG.scriptId;
            script.textContent = '(' + pageBridgeMain.toString() + ')(' + JSON.stringify({
                eventName: CFG.eventName,
                debugEnabled: CFG.debugEnabled,
                debugLevel: CFG.debugLevel
            }) + ');';
            document.documentElement.appendChild(script);
            script.remove();
            debugLog('info', 'injectBridge complete');
        }
        catch (error) {
            debugLog('error', 'injectBridge failed', {
                error: String(error && error.message ? error.message : error)
            });
        }
    }

    function onBridgeEvent(event) {
        const detail = event && event.detail ? event.detail : null;

        if (!detail || typeof detail !== 'object') {
            return;
        }

        if (detail.type === 'request') {
            recordRequest(detail.url || '', detail.source || 'bridge');
            return;
        }

        if (detail.type === 'candidate') {
            enqueueCandidate(detail.downloadUrl || '', detail.requestUrl || '', detail.fileName || '', detail.source || 'bridge');
        }
    }

    async function saveBlob(downloadUrl, preferredFilename) {
        debugLog('info', 'saveBlob begin', {
            downloadUrl: downloadUrl,
            preferredFilename: preferredFilename
        });

        recordRequest(downloadUrl, 'fallback.file');

        const response = await fetch(downloadUrl, {
            credentials: 'include'
        });

        debugLog('info', 'saveBlob response received', {
            downloadUrl: downloadUrl,
            status: response.status,
            ok: response.ok,
            contentDisposition: response.headers.get('content-disposition')
        });

        if (!response.ok) {
            throw new Error('Download URL HTTP ' + response.status);
        }

        const blob = await response.blob();

        const resolvedFilename =
            parseContentDisposition(response.headers.get('content-disposition')) ||
            trimFilename(preferredFilename || '') ||
            'download.bin';

        const filename = sanitizeFilename(resolvedFilename);
        const objectUrl = URL.createObjectURL(blob);

        debugLog('info', 'saveBlob prepared object URL', {
            filename: filename,
            objectUrl: objectUrl,
            size: blob.size,
            type: blob.type
        });

        try {
            const anchor = document.createElement('a');
            anchor.href = objectUrl;
            anchor.download = filename;
            anchor.style.display = 'none';
            anchor.dataset.chatgptDownloadFixTemp = '1';

            (document.body || document.documentElement).appendChild(anchor);
            anchor.click();
            anchor.remove();
        }
        finally {
            setTimeout(function () {
                URL.revokeObjectURL(objectUrl);
            }, 10000);
        }

        return filename;
    }

    async function evaluateJob(job) {
        debugLog('info', 'evaluateJob begin', {
            job: job
        });

        const candidate = await waitForCandidate(job.startedAt, CFG.candidateWaitMs);

        debugLog('info', 'evaluateJob candidate wait finished', {
            job: job,
            candidate: candidate,
            currentCandidates: runtime.candidates.slice()
        });

        if (!candidate) {
            if (visibleTextExists('Starting download')) {
                writeState({
                    status: 'broken',
                    nativeStatus: 'broken',
                    workaroundStatus: 'unavailable',
                    lastBrokenAt: nowMs(),
                    lastMessage: 'No usable download URL was recovered for ' + job.label
                });

                showToast('Download fix needs another update', 'No usable download URL was recovered for ' + job.label + '.');
                return;
            }

            writeState({
                status: 'healthy',
                nativeStatus: 'healthy',
                workaroundStatus: 'not_needed',
                lastHealthyAt: nowMs(),
                lastMessage: 'No workaround needed for ' + job.label
            });

            return;
        }

        await waitMs(CFG.nativeFollowupWaitMs);

        const requestObserved = wasRequestObservedSince(candidate.downloadUrl, Math.min(job.startedAt, candidate.observedAt));

        debugLog('info', 'evaluateJob native followup check complete', {
            job: job,
            candidate: candidate,
            requestObserved: requestObserved
        });

        if (requestObserved) {
            writeState({
                status: 'healthy',
                nativeStatus: 'healthy',
                workaroundStatus: 'not_needed',
                lastHealthyAt: nowMs(),
                lastMessage: 'Observed native request for returned download URL for ' + job.label
            });

            return;
        }

        candidate.used = true;

        writeState({
            status: 'working',
            nativeStatus: 'broken',
            workaroundStatus: 'running',
            lastMessage: 'Running fallback download for ' + job.label
        });

        showToast('Fixing stuck download', 'Fetching ' + job.label + ' directly from ChatGPT\'s returned download URL.');

        const savedFilename = await saveBlob(candidate.downloadUrl, candidate.fileName || job.label);

        writeState({
            status: 'worked_around',
            nativeStatus: 'broken',
            workaroundStatus: 'succeeded',
            lastWorkedAroundAt: nowMs(),
            lastMessage: 'Fallback saveBlob succeeded for ' + savedFilename
        });

        debugLog('info', 'evaluateJob fallback saveBlob completed', {
            job: job,
            candidate: candidate,
            savedFilename: savedFilename
        });
    }

    function handleClick(event) {
        const control = event.target instanceof Element ? event.target.closest('button, a, [role="button"]') : null;

        if (!control) {
            return;
        }

        if (control.dataset && control.dataset.chatgptDownloadFixTemp === '1') {
            debugLog('debug', 'handleClick ignored synthetic temp control');
            return;
        }

        const rawText = String(control.textContent || '');
        const normalizedText = rawText.replace(/\s+/g, ' ').trim();
        const label = trimFilename(normalizedText);

        if (!/\.[A-Za-z0-9]{1,12}$/.test(label)) {
            return;
        }

        if (!control.closest('[data-message-id]')) {
            return;
        }

        const job = {
            id: runtime.nextJobId++,
            startedAt: nowMs(),
            label: label
        };

        debugLog('info', 'handleClick created job', {
            job: job
        });

        console.info('[ChatGPT Download Fix] Observed file click:', job);

        evaluateJob(job).catch(function (error) {
            const message = String(error && error.message ? error.message : error);

            debugLog('error', 'handleClick evaluateJob failed', {
                job: job,
                error: message
            });

            writeState({
                status: 'broken',
                nativeStatus: 'broken',
                workaroundStatus: 'failed',
                lastBrokenAt: nowMs(),
                lastMessage: 'Fix failed for ' + job.label + ': ' + message
            });

            showToast('Download fix failed', message);
        });
    }

    injectBridge();
    window.addEventListener(CFG.eventName, onBridgeEvent, true);
    document.addEventListener('click', handleClick, true);

    window.addEventListener('load', function () {
        const state = readState();
        debugLog('info', 'window load fired', {
            state: state,
            requestLogLength: runtime.requestLog.length,
            candidatesLength: runtime.candidates.length,
            waiterCount: runtime.candidateWaiters.length
        });
        console.info('[ChatGPT Download Fix] Loaded:', state);
    });

    debugLog('info', 'userscript bootstrap complete', {
        locationHref: location.href,
        debugLevel: CFG.debugLevel
    });
})();
