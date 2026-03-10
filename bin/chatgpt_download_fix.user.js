// ==UserScript==
// @name         ChatGPT Download Fix
// @namespace    local.wbraswell.chatgpt
// @version      0.005
// @description  Fix ChatGPT file downloads stuck on 'Starting download'.
// @match        https://chatgpt.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

(function () {
    'use strict';

    const CFG = {
        eventName: '__chatgpt_download_fix_bridge_v004__',
        scriptId: 'chatgpt-download-fix-bridge-v004',
        stateKey: 'chatgpt_download_fix_state_v0_004',
        probeWaitMs: 2500,
        nativeFollowupWaitMs: 900,
        toastMs: 5000,
        requestTtlMs: 20000,
        candidateTtlMs: 20000
    };

    const DEBUG = true;

    const runtime = {
        requestLog: [],
        candidates: [],
        nextJobId: 1,
        nextCandidateId: 1,
        debugSeq: 1
    };

    function debugLog(level, message, detail) {
        if (!DEBUG) {
            return;
        }

        const seq = runtime.debugSeq++;
        const prefix = '[ChatGPT Download Fix v0.005 #' + seq + '] ' + message;

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

    function normalizeUrl(input) {
        try {
            const normalized = new URL(String(input || ''), location.href).toString();
            debugLog('log', 'normalizeUrl success', {
                input: input,
                normalized: normalized
            });
            return normalized;
        }
        catch (error) {
            const fallback = String(input || '');
            debugLog('warn', 'normalizeUrl fallback', {
                input: input,
                fallback: fallback,
                error: String(error && error.message ? error.message : error)
            });
            return fallback;
        }
    }

    function sanitizeFilename(name) {
        const cleaned = String(name || '').replace(/[\\/\0]/g, '_').trim();
        const result = cleaned || 'download.bin';
        debugLog('log', 'sanitizeFilename', {
            input: name,
            result: result
        });
        return result;
    }

    function readState() {
        try {
            const raw = localStorage.getItem(CFG.stateKey);
            const parsed = raw ? JSON.parse(raw) : { status: 'unknown', lastMessage: '' };
            debugLog('log', 'readState', {
                raw: raw,
                parsed: parsed
            });
            return parsed;
        }
        catch (error) {
            const fallback = { status: 'unknown', lastMessage: '' };
            debugLog('warn', 'readState failed, using fallback', {
                error: String(error && error.message ? error.message : error),
                fallback: fallback
            });
            return fallback;
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

        let host = document.getElementById('chatgpt-download-fix-toast-host-v004');

        if (!host) {
            debugLog('log', 'showToast creating host and style');

            const style = document.createElement('style');
            style.textContent = '#chatgpt-download-fix-toast-host-v004{position:fixed;right:16px;bottom:16px;z-index:2147483647;display:flex;flex-direction:column;gap:8px;pointer-events:none}#chatgpt-download-fix-toast-host-v004 .toast{max-width:420px;padding:10px 12px;border-radius:10px;background:rgba(24,24,27,.96);color:#fff;font:13px/1.45 sans-serif;box-shadow:0 12px 30px rgba(0,0,0,.35)}#chatgpt-download-fix-toast-host-v004 .title{font-weight:700;margin-bottom:2px}';
            document.documentElement.appendChild(style);

            host = document.createElement('div');
            host.id = 'chatgpt-download-fix-toast-host-v004';
            document.documentElement.appendChild(host);
        }

        const box = document.createElement('div');
        box.className = 'toast';
        box.innerHTML = '<div class="title"></div><div class="body"></div>';
        box.querySelector('.title').textContent = title;
        box.querySelector('.body').textContent = body;
        host.appendChild(box);

        debugLog('log', 'showToast appended', {
            title: title,
            body: body
        });

        setTimeout(function () {
            debugLog('log', 'showToast removing', {
                title: title,
                body: body
            });
            box.remove();
        }, CFG.toastMs);
    }

    function pruneRequests() {
        const before = runtime.requestLog.length;
        const cutoff = nowMs() - CFG.requestTtlMs;

        runtime.requestLog = runtime.requestLog.filter(function (entry) {
            return entry.observedAt >= cutoff;
        });

        debugLog('log', 'pruneRequests', {
            cutoff: cutoff,
            before: before,
            after: runtime.requestLog.length
        });
    }

    function recordRequest(url, source) {
        const normalized = normalizeUrl(url);

        if (!/^https?:\/\//i.test(normalized)) {
            debugLog('warn', 'recordRequest ignored non-http url', {
                input: url,
                normalized: normalized,
                source: source || 'unknown'
            });
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

        const found = runtime.requestLog.some(function (entry) {
            return entry.observedAt >= startedAt && entry.url === normalized;
        });

        debugLog('info', 'wasRequestObservedSince', {
            url: url,
            normalized: normalized,
            startedAt: startedAt,
            found: found,
            matchingEntries: runtime.requestLog.filter(function (entry) {
                return entry.observedAt >= startedAt && entry.url === normalized;
            })
        });

        return found;
    }

    function pruneCandidates() {
        const before = runtime.candidates.length;
        const cutoff = nowMs() - CFG.candidateTtlMs;

        runtime.candidates = runtime.candidates.filter(function (entry) {
            return entry.observedAt >= cutoff;
        });

        debugLog('log', 'pruneCandidates', {
            cutoff: cutoff,
            before: before,
            after: runtime.candidates.length
        });
    }

    function enqueueCandidate(downloadUrl, requestUrl, fileName, source) {
        const normalized = normalizeUrl(downloadUrl);

        if (!/^https?:\/\//i.test(normalized)) {
            debugLog('warn', 'enqueueCandidate ignored non-http downloadUrl', {
                downloadUrl: downloadUrl,
                normalized: normalized,
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
            fileName: sanitizeFilename(fileName || ''),
            source: source || 'unknown'
        };

        runtime.candidates.push(candidate);

        debugLog('info', 'enqueueCandidate stored', {
            candidate: candidate,
            candidatesLength: runtime.candidates.length
        });

        return candidate;
    }

    function pickBestCandidate(startedAt) {
        pruneCandidates();

        const floor = startedAt - 1500;
        let best = null;

        debugLog('log', 'pickBestCandidate begin', {
            startedAt: startedAt,
            floor: floor,
            candidates: runtime.candidates.slice()
        });

        for (const candidate of runtime.candidates) {
            if (candidate.used) {
                debugLog('log', 'pickBestCandidate skip used candidate', candidate);
                continue;
            }

            if (candidate.observedAt < floor) {
                debugLog('log', 'pickBestCandidate skip old candidate', candidate);
                continue;
            }

            if (!best) {
                best = candidate;
                debugLog('log', 'pickBestCandidate initial best', best);
                continue;
            }

            const candidateIsMetadata = candidate.requestUrl.indexOf('/interpreter/download') !== -1;
            const bestIsMetadata = best.requestUrl.indexOf('/interpreter/download') !== -1;

            if (candidateIsMetadata && !bestIsMetadata) {
                best = candidate;
                debugLog('log', 'pickBestCandidate preferred metadata candidate', best);
                continue;
            }

            if (candidate.observedAt > best.observedAt) {
                best = candidate;
                debugLog('log', 'pickBestCandidate newer candidate won', best);
            }
        }

        debugLog('info', 'pickBestCandidate result', {
            startedAt: startedAt,
            best: best
        });

        return best;
    }

    function parseConversationId() {
        const match = String(location.pathname || '').match(/^\/c\/([0-9a-f-]+)/i);
        const conversationId = match && match[1] ? match[1] : '';

        debugLog('log', 'parseConversationId', {
            pathname: location.pathname,
            conversationId: conversationId
        });

        return conversationId;
    }

    function getMessageId(control) {
        const root = control.closest('[data-message-id]');
        const messageId = root ? String(root.getAttribute('data-message-id') || '') : '';

        debugLog('log', 'getMessageId', {
            control: control,
            messageId: messageId
        });

        return messageId;
    }

    function isVisibleElement(node) {
        if (!(node instanceof Element)) {
            debugLog('log', 'isVisibleElement false, not an Element', {
                node: node
            });
            return false;
        }

        const style = getComputedStyle(node);

        if (style.display === 'none' || style.visibility === 'hidden') {
            debugLog('log', 'isVisibleElement false, hidden by style', {
                node: node,
                display: style.display,
                visibility: style.visibility
            });
            return false;
        }

        const rect = node.getBoundingClientRect();
        const visible = rect.width > 0 && rect.height > 0;

        debugLog('log', 'isVisibleElement result', {
            node: node,
            rect: {
                width: rect.width,
                height: rect.height
            },
            visible: visible
        });

        return visible;
    }

    function visibleTextExists(text) {
        const root = document.body || document.documentElement;
        const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT);
        let node = walker.nextNode();

        debugLog('log', 'visibleTextExists begin', {
            text: text
        });

        while (node) {
            if (node.textContent && node.textContent.indexOf(text) !== -1 && isVisibleElement(node)) {
                debugLog('info', 'visibleTextExists matched', {
                    text: text,
                    node: node,
                    textContent: node.textContent
                });
                return true;
            }

            node = walker.nextNode();
        }

        debugLog('info', 'visibleTextExists no match', {
            text: text
        });

        return false;
    }

    function injectBridge() {
        if (document.getElementById(CFG.scriptId)) {
            debugLog('warn', 'injectBridge skipped, bridge script already exists', {
                scriptId: CFG.scriptId
            });
            return;
        }

        debugLog('info', 'injectBridge start', {
            eventName: CFG.eventName,
            scriptId: CFG.scriptId
        });

        const src = '(function(){' +
            'if(window.__chatgptDownloadFixBridgeV004){console.info("[ChatGPT Download Fix Bridge v0.005] already installed");return;}window.__chatgptDownloadFixBridgeV004=true;console.info("[ChatGPT Download Fix Bridge v0.005] installing bridge");' +
            'var EVENT=' + JSON.stringify(CFG.eventName) + ';' +
            'function emit(detail){try{console.info("[ChatGPT Download Fix Bridge v0.005] emit",detail);window.dispatchEvent(new CustomEvent(EVENT,{detail:detail}))}catch(error){console.error("[ChatGPT Download Fix Bridge v0.005] emit failed",error,detail)}}' +
            'function norm(input){try{var normalized=new URL(String(input||""),location.href).toString();console.log("[ChatGPT Download Fix Bridge v0.005] norm success",{input:input,normalized:normalized});return normalized}catch(error){var fallback=String(input||"");console.warn("[ChatGPT Download Fix Bridge v0.005] norm fallback",{input:input,fallback:fallback,error:String(error&&error.message?error.message:error)});return fallback}}' +
            'function req(url,source){var u=norm(url);if(/^https?:\\\\/\\\\//i.test(u)){console.info("[ChatGPT Download Fix Bridge v0.005] request observed",{url:u,source:source||"page"});emit({type:"request",url:u,source:source||"page"})}else{console.warn("[ChatGPT Download Fix Bridge v0.005] request ignored",{url:url,normalized:u,source:source||"page"})}}' +
            'function cand(url,requestUrl,fileName,source){var u=norm(url);if(/^https?:\\\\/\\\\//i.test(u)){console.info("[ChatGPT Download Fix Bridge v0.005] candidate observed",{downloadUrl:u,requestUrl:requestUrl,fileName:fileName,source:source||"page"});emit({type:"candidate",downloadUrl:u,requestUrl:norm(requestUrl||""),fileName:String(fileName||""),source:source||"page"})}else{console.warn("[ChatGPT Download Fix Bridge v0.005] candidate ignored",{downloadUrl:url,normalized:u,requestUrl:requestUrl,fileName:fileName,source:source||"page"})}}' +
            'function inspect(text,requestUrl,source){console.info("[ChatGPT Download Fix Bridge v0.005] inspect begin",{requestUrl:requestUrl,source:source,textLength:text?String(text).length:0});if(!text){console.warn("[ChatGPT Download Fix Bridge v0.005] inspect empty text",{requestUrl:requestUrl,source:source});return;}try{var payload=JSON.parse(text);console.info("[ChatGPT Download Fix Bridge v0.005] inspect parsed JSON",payload);if(payload&&typeof payload.download_url==="string"&&payload.download_url){cand(payload.download_url,requestUrl,payload.file_name||"",source);return}console.info("[ChatGPT Download Fix Bridge v0.005] inspect JSON had no direct download_url",{requestUrl:requestUrl,source:source})}catch(error){console.warn("[ChatGPT Download Fix Bridge v0.005] inspect JSON parse failed",{requestUrl:requestUrl,source:source,error:String(error&&error.message?error.message:error)})}var m=text.match(/"download_url"\\\\s*:\\\\s*"((?:\\\\\\\\.|[^"])*)"/);if(m){console.info("[ChatGPT Download Fix Bridge v0.005] inspect regex matched",m[1]);try{cand(JSON.parse("\\\"" + m[1].replace(/\\\\\\\\/g,"\\\\\\\\\\\\\\\\").replace(/\\"/g,"\\\\\\\\\\"") + "\\\""),requestUrl,"",source)}catch(error2){console.warn("[ChatGPT Download Fix Bridge v0.005] inspect regex JSON decode failed, using fallback",{error:String(error2&&error2.message?error2.message:error2)});cand(m[1].replace(/\\\\\\\\\\//g,"/").replace(/\\\\\\\\"/g,"\\""),requestUrl,"",source)}}else{console.info("[ChatGPT Download Fix Bridge v0.005] inspect found no regex match",{requestUrl:requestUrl,source:source})}}' +
            'if(typeof fetch==="function"){console.info("[ChatGPT Download Fix Bridge v0.005] patching page fetch");var of=fetch;window.fetch=function(){var args=[].slice.call(arguments);var url=norm(args[0]&&args[0].url?args[0].url:args[0]);console.info("[ChatGPT Download Fix Bridge v0.005] page fetch called",{url:url,args:args});req(url,"page.fetch");return of.apply(this,args).then(function(resp){try{var ct=resp.headers.get("content-type")||"";console.info("[ChatGPT Download Fix Bridge v0.005] page fetch response",{url:url,status:resp.status,ok:resp.ok,contentType:ct});if(url.indexOf(location.origin+"/backend-api/")===0&&(ct.indexOf("json")!==-1)){resp.clone().text().then(function(text){console.info("[ChatGPT Download Fix Bridge v0.005] page fetch cloned text ready",{url:url,length:text?text.length:0});inspect(text,url,"page.fetch")}).catch(function(error){console.error("[ChatGPT Download Fix Bridge v0.005] page fetch clone text failed",error)})}else{console.info("[ChatGPT Download Fix Bridge v0.005] page fetch response not inspected",{url:url,contentType:ct})}}catch(error){console.error("[ChatGPT Download Fix Bridge v0.005] page fetch response handling failed",error)}return resp}).catch(function(error){console.error("[ChatGPT Download Fix Bridge v0.005] page fetch rejected",{url:url,error:error});throw error})}}else{console.warn("[ChatGPT Download Fix Bridge v0.005] no page fetch available")}' +
            'if(typeof XMLHttpRequest==="function"){console.info("[ChatGPT Download Fix Bridge v0.005] patching page XHR");var oo=XMLHttpRequest.prototype.open;var os=XMLHttpRequest.prototype.send;XMLHttpRequest.prototype.open=function(method,url){this.__cdf_url=norm(url);console.info("[ChatGPT Download Fix Bridge v0.005] page XHR open",{method:method,url:url,normalizedUrl:this.__cdf_url});return oo.apply(this,arguments)};XMLHttpRequest.prototype.send=function(){console.info("[ChatGPT Download Fix Bridge v0.005] page XHR send",{url:this.__cdf_url||"",responseType:this.responseType});req(this.__cdf_url||"","page.xhr");this.addEventListener("loadend",function(){try{var url=this.__cdf_url||"";var ct=this.getResponseHeader("content-type")||"";console.info("[ChatGPT Download Fix Bridge v0.005] page XHR loadend",{url:url,status:this.status,responseType:this.responseType,contentType:ct});if(url.indexOf(location.origin+"/backend-api/")!==0||ct.indexOf("json")==-1){console.info("[ChatGPT Download Fix Bridge v0.005] page XHR response not inspected",{url:url,contentType:ct});return}var text=this.responseType==="json"?JSON.stringify(this.response):(this.responseType===""||this.responseType==="text"?this.responseText||"":"");console.info("[ChatGPT Download Fix Bridge v0.005] page XHR text ready",{url:url,length:text?text.length:0});inspect(text,url,"page.xhr")}catch(error){console.error("[ChatGPT Download Fix Bridge v0.005] page XHR loadend handling failed",error)}});return os.apply(this,arguments)}}else{console.warn("[ChatGPT Download Fix Bridge v0.005] no page XHR available")}' +
            'console.info("[ChatGPT Download Fix Bridge v0.005] bridge installed successfully");' +
            '})();';

        const script = document.createElement('script');
        script.id = CFG.scriptId;
        script.textContent = src;
        document.documentElement.appendChild(script);
        script.remove();

        debugLog('info', 'injectBridge complete');
    }

    function onBridgeEvent(event) {
        const detail = event && event.detail ? event.detail : null;

        debugLog('info', 'onBridgeEvent received', {
            detail: detail
        });

        if (!detail || typeof detail !== 'object') {
            debugLog('warn', 'onBridgeEvent ignored invalid detail', {
                detail: detail
            });
            return;
        }

        if (detail.type === 'request') {
            debugLog('log', 'onBridgeEvent processing request detail', detail);
            recordRequest(detail.url || '', detail.source || 'bridge');
            return;
        }

        if (detail.type === 'candidate') {
            debugLog('log', 'onBridgeEvent processing candidate detail', detail);
            enqueueCandidate(detail.downloadUrl || '', detail.requestUrl || '', detail.fileName || '', detail.source || 'bridge');
            return;
        }

        debugLog('warn', 'onBridgeEvent ignored unknown detail type', detail);
    }

    async function requestMetadata(job) {
        const sandboxPath = '/mnt/data/' + job.label;
        const url = location.origin +
            '/backend-api/conversation/' + encodeURIComponent(job.conversationId) +
            '/interpreter/download?message_id=' + encodeURIComponent(job.messageId) +
            '&sandbox_path=' + encodeURIComponent(sandboxPath);

        debugLog('info', 'requestMetadata begin', {
            job: job,
            sandboxPath: sandboxPath,
            url: url
        });

        recordRequest(url, 'fallback.metadata');

        const response = await fetch(url, { credentials: 'include' });

        debugLog('info', 'requestMetadata response received', {
            url: url,
            status: response.status,
            ok: response.ok
        });

        if (!response.ok) {
            throw new Error('Metadata request HTTP ' + response.status);
        }

        const payload = await response.json();

        debugLog('info', 'requestMetadata payload', {
            url: url,
            payload: payload
        });

        if (!payload || payload.status !== 'success' || typeof payload.download_url !== 'string' || !payload.download_url) {
            throw new Error('Metadata response did not contain a usable download_url');
        }

        const candidate = enqueueCandidate(payload.download_url, url, payload.file_name || job.label, 'fallback.metadata');

        debugLog('info', 'requestMetadata returning candidate', {
            job: job,
            candidate: candidate
        });

        return candidate;
    }

    function parseContentDisposition(headerValue) {
        debugLog('log', 'parseContentDisposition begin', {
            headerValue: headerValue
        });

        if (!headerValue) {
            debugLog('log', 'parseContentDisposition no headerValue');
            return null;
        }

        let match = headerValue.match(/filename\*=UTF-8''([^;]+)/i);
        if (match && match[1]) {
            try {
                const decoded = decodeURIComponent(match[1]);
                debugLog('info', 'parseContentDisposition matched filename*', {
                    raw: match[1],
                    decoded: decoded
                });
                return decoded;
            }
            catch (error) {
                debugLog('warn', 'parseContentDisposition filename* decode failed', {
                    raw: match[1],
                    error: String(error && error.message ? error.message : error)
                });
                return match[1];
            }
        }

        match = headerValue.match(/filename="([^"]+)"/i);
        if (match && match[1]) {
            debugLog('info', 'parseContentDisposition matched quoted filename', {
                filename: match[1]
            });
            return match[1];
        }

        match = headerValue.match(/filename=([^;]+)/i);
        if (match && match[1]) {
            const trimmed = match[1].trim();
            debugLog('info', 'parseContentDisposition matched bare filename', {
                filename: trimmed
            });
            return trimmed;
        }

        debugLog('log', 'parseContentDisposition no filename match', {
            headerValue: headerValue
        });

        return null;
    }

    async function saveBlob(downloadUrl, preferredFilename) {
        debugLog('info', 'saveBlob begin', {
            downloadUrl: downloadUrl,
            preferredFilename: preferredFilename
        });

        recordRequest(downloadUrl, 'fallback.file');

        const response = await fetch(downloadUrl, { credentials: 'include' });

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

        debugLog('info', 'saveBlob blob received', {
            size: blob.size,
            type: blob.type
        });

        const filename = sanitizeFilename(
            parseContentDisposition(response.headers.get('content-disposition')) ||
            preferredFilename
        );

        const objectUrl = URL.createObjectURL(blob);

        debugLog('info', 'saveBlob object URL created', {
            filename: filename,
            objectUrl: objectUrl
        });

        try {
            const anchor = document.createElement('a');
            anchor.href = objectUrl;
            anchor.download = filename;
            anchor.style.display = 'none';

            (document.body || document.documentElement).appendChild(anchor);

            debugLog('info', 'saveBlob clicking temporary anchor', {
                filename: filename,
                anchorHref: anchor.href,
                anchorDownload: anchor.download
            });

            anchor.click();
            anchor.remove();

            debugLog('info', 'saveBlob temporary anchor removed', {
                filename: filename
            });
        }
        finally {
            setTimeout(function () {
                debugLog('log', 'saveBlob revoking object URL', {
                    filename: filename,
                    objectUrl: objectUrl
                });
                URL.revokeObjectURL(objectUrl);
            }, 10000);
        }
    }

    async function evaluateJob(job) {
        debugLog('info', 'evaluateJob begin', {
            job: job
        });

        await new Promise(function (resolve) {
            debugLog('log', 'evaluateJob waiting probeWaitMs', {
                probeWaitMs: CFG.probeWaitMs,
                job: job
            });
            setTimeout(resolve, CFG.probeWaitMs);
        });

        debugLog('info', 'evaluateJob probe wait finished', {
            job: job,
            currentCandidates: runtime.candidates.slice(),
            currentRequests: runtime.requestLog.slice()
        });

        let candidate = pickBestCandidate(job.startedAt);

        debugLog('info', 'evaluateJob initial candidate lookup result', {
            job: job,
            candidate: candidate
        });

        if (!candidate) {
            try {
                debugLog('info', 'evaluateJob no candidate found, requesting metadata', {
                    job: job
                });
                candidate = await requestMetadata(job);
                debugLog('info', 'evaluateJob metadata request produced candidate', {
                    job: job,
                    candidate: candidate
                });
            }
            catch (error) {
                debugLog('warn', 'evaluateJob metadata probe failed', {
                    job: job,
                    error: String(error && error.message ? error.message : error)
                });
            }
        }

        if (!candidate) {
            debugLog('warn', 'evaluateJob still no candidate after metadata attempt', {
                job: job
            });

            if (visibleTextExists('Starting download')) {
                debugLog('warn', 'evaluateJob saw visible "Starting download" with no candidate', {
                    job: job
                });

                writeState({
                    status: 'broken',
                    lastBrokenAt: nowMs(),
                    lastMessage: 'No usable download URL was captured for ' + job.label
                });

                showToast('Download fix needs another update', 'No usable download URL was recovered for ' + job.label + '.');
                return;
            }

            debugLog('info', 'evaluateJob no candidate and no visible spinner, marking healthy', {
                job: job
            });

            writeState({
                status: 'healthy',
                lastHealthyAt: nowMs(),
                lastMessage: 'No fallback needed for ' + job.label
            });

            return;
        }

        await new Promise(function (resolve) {
            debugLog('log', 'evaluateJob waiting nativeFollowupWaitMs', {
                nativeFollowupWaitMs: CFG.nativeFollowupWaitMs,
                job: job,
                candidate: candidate
            });
            setTimeout(resolve, CFG.nativeFollowupWaitMs);
        });

        const requestObserved = wasRequestObservedSince(candidate.downloadUrl, Math.min(job.startedAt, candidate.observedAt));

        debugLog('info', 'evaluateJob native followup check complete', {
            job: job,
            candidate: candidate,
            requestObserved: requestObserved,
            requests: runtime.requestLog.slice()
        });

        if (requestObserved) {
            debugLog('info', 'evaluateJob observed native file request, marking healthy', {
                job: job,
                candidate: candidate
            });

            writeState({
                status: 'healthy',
                lastHealthyAt: nowMs(),
                lastMessage: 'Observed native request for returned download URL for ' + job.label
            });

            return;
        }

        candidate.used = true;

        debugLog('warn', 'evaluateJob did not observe native file request, running fallback saveBlob', {
            job: job,
            candidate: candidate
        });

        writeState({
            status: 'broken',
            lastBrokenAt: nowMs(),
            lastMessage: 'No native request was observed for returned download URL for ' + job.label
        });

        showToast('Fixing stuck download', 'Fetching ' + job.label + ' directly from ChatGPT\'s returned download URL.');

        await saveBlob(candidate.downloadUrl, candidate.fileName || job.label);

        debugLog('info', 'evaluateJob fallback saveBlob completed', {
            job: job,
            candidate: candidate
        });
    }

    function handleClick(event) {
        debugLog('info', 'handleClick begin', {
            eventType: event && event.type ? event.type : '',
            target: event ? event.target : null
        });

        const control = event.target instanceof Element ? event.target.closest('button, a, [role="button"]') : null;

        debugLog('log', 'handleClick nearest control', {
            control: control
        });

        if (!control) {
            debugLog('log', 'handleClick ignored, no clickable control found');
            return;
        }

        const rawText = String(control.textContent || '');
        const normalizedText = rawText.replace(/\s+/g, ' ').trim();
        const label = sanitizeFilename(normalizedText);

        debugLog('log', 'handleClick computed label', {
            rawText: rawText,
            normalizedText: normalizedText,
            label: label
        });

        if (!/\.[A-Za-z0-9]{1,12}$/.test(label)) {
            debugLog('log', 'handleClick ignored, label does not look like filename', {
                label: label
            });
            return;
        }

        if (!control.closest('[data-message-id]')) {
            debugLog('log', 'handleClick ignored, control not inside [data-message-id]', {
                label: label,
                control: control
            });
            return;
        }

        const job = {
            id: runtime.nextJobId++,
            startedAt: nowMs(),
            label: label,
            messageId: getMessageId(control),
            conversationId: parseConversationId()
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
                lastBrokenAt: nowMs(),
                lastMessage: 'Fix failed for ' + job.label + ': ' + message
            });

            showToast('Download fix failed', message);
        });
    }

    debugLog('info', 'userscript bootstrap begin', {
        locationHref: location.href,
        CFG: CFG
    });

    injectBridge();

    debugLog('info', 'adding bridge event listener', {
        eventName: CFG.eventName
    });
    window.addEventListener(CFG.eventName, onBridgeEvent, true);

    debugLog('info', 'adding click event listener');
    document.addEventListener('click', handleClick, true);

    window.addEventListener('load', function () {
        const state = readState();
        debugLog('info', 'window load fired', {
            state: state,
            requestLogLength: runtime.requestLog.length,
            candidatesLength: runtime.candidates.length
        });
        console.info('[ChatGPT Download Fix] Loaded:', state);
    });

    debugLog('info', 'userscript bootstrap complete');
})();
