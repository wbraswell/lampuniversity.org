// ==UserScript==
// @name         ChatGPT Download Fix
// @namespace    local.wbraswell.chatgpt
// @version      0.001
// @description  Work around stuck ChatGPT file downloads, while periodically probing whether the native flow has been fixed.
// @match        https://chatgpt.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

(function () {
    'use strict';

    const CONFIG = {
        probeIntervalMs: 12 * 60 * 60 * 1000,
        probeWaitMs: 3000,
        toastMs: 5000,
        stateKey: 'chatgpt_download_fix_state_v0_001',
        styleId: 'chatgpt-download-fix-style-v0-001',
        toastHostId: 'chatgpt-download-fix-toast-host-v0-001'
    };

    function nowMs() {
        return Date.now();
    }

    function readState() {
        try {
            const raw = localStorage.getItem(CONFIG.stateKey);
            if (!raw) {
                return {
                    mode: 'probe',
                    lastProbeAt: 0,
                    lastBrokenAt: 0,
                    lastHealthyAt: 0,
                    lastMessage: ''
                };
            }
            const parsed = JSON.parse(raw);
            return {
                mode: parsed.mode === 'workaround' ? 'workaround' : 'probe',
                lastProbeAt: Number(parsed.lastProbeAt) || 0,
                lastBrokenAt: Number(parsed.lastBrokenAt) || 0,
                lastHealthyAt: Number(parsed.lastHealthyAt) || 0,
                lastMessage: typeof parsed.lastMessage === 'string' ? parsed.lastMessage : ''
            };
        }
        catch (error) {
            console.warn('[ChatGPT Download Fix] Failed to read state:', error);
            return {
                mode: 'probe',
                lastProbeAt: 0,
                lastBrokenAt: 0,
                lastHealthyAt: 0,
                lastMessage: ''
            };
        }
    }

    function writeState(patch) {
        const current = readState();
        const next = Object.assign({}, current, patch);
        localStorage.setItem(CONFIG.stateKey, JSON.stringify(next));
        return next;
    }

    function ensureStyle() {
        if (document.getElementById(CONFIG.styleId)) {
            return;
        }
        const style = document.createElement('style');
        style.id = CONFIG.styleId;
        style.textContent = [
            '#' + CONFIG.toastHostId + ' {',
            '    position: fixed;',
            '    right: 16px;',
            '    bottom: 16px;',
            '    z-index: 2147483647;',
            '    display: flex;',
            '    flex-direction: column;',
            '    gap: 8px;',
            '    pointer-events: none;',
            '}',
            '.' + CONFIG.toastHostId + '__toast {',
            '    max-width: 420px;',
            '    padding: 10px 12px;',
            '    border-radius: 10px;',
            '    background: rgba(24, 24, 27, 0.96);',
            '    color: #ffffff;',
            '    font: 13px/1.4 sans-serif;',
            '    box-shadow: 0 12px 30px rgba(0, 0, 0, 0.35);',
            '    pointer-events: auto;',
            '}',
            '.' + CONFIG.toastHostId + '__title {',
            '    font-weight: 700;',
            '    margin-bottom: 2px;',
            '}',
            '.' + CONFIG.toastHostId + '__body {',
            '    opacity: 0.95;',
            '}'
        ].join('\n');
        document.documentElement.appendChild(style);
    }

    function ensureToastHost() {
        ensureStyle();
        let host = document.getElementById(CONFIG.toastHostId);
        if (host) {
            return host;
        }
        host = document.createElement('div');
        host.id = CONFIG.toastHostId;
        document.documentElement.appendChild(host);
        return host;
    }

    function showToast(title, body) {
        const host = ensureToastHost();
        const toast = document.createElement('div');
        toast.className = CONFIG.toastHostId + '__toast';

        const titleNode = document.createElement('div');
        titleNode.className = CONFIG.toastHostId + '__title';
        titleNode.textContent = title;
        toast.appendChild(titleNode);

        const bodyNode = document.createElement('div');
        bodyNode.className = CONFIG.toastHostId + '__body';
        bodyNode.textContent = body;
        toast.appendChild(bodyNode);

        host.appendChild(toast);
        window.setTimeout(function () {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, CONFIG.toastMs);
    }

    function getConversationId() {
        const match = window.location.pathname.match(/^\/c\/([^/?#]+)/);
        return match ? match[1] : null;
    }

    function decodeHtmlEntities(text) {
        const textarea = document.createElement('textarea');
        textarea.innerHTML = text;
        return textarea.value;
    }

    function parseFilenameFromContentDisposition(headerValue) {
        if (!headerValue) {
            return null;
        }

        let match = headerValue.match(/filename\*=UTF-8''([^;]+)/i);
        if (match && match[1]) {
            try {
                return decodeURIComponent(match[1]);
            }
            catch (error) {
                return decodeHtmlEntities(match[1]);
            }
        }

        match = headerValue.match(/filename="([^"]+)"/i);
        if (match && match[1]) {
            return decodeHtmlEntities(match[1]);
        }

        match = headerValue.match(/filename=([^;]+)/i);
        if (match && match[1]) {
            return decodeHtmlEntities(match[1].trim());
        }

        return null;
    }

    function sanitizeFilename(filename) {
        if (!filename) {
            return 'download.bin';
        }
        return String(filename).replace(/[\\/\0]/g, '_').trim() || 'download.bin';
    }

    function buildSandboxPath(filename) {
        return '/mnt/data/' + filename;
    }

    function isVisible(node) {
        if (!node) {
            return false;
        }
        if (!(node instanceof Element)) {
            return false;
        }
        const style = window.getComputedStyle(node);
        if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
            return false;
        }
        const rect = node.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
    }

    function findVisibleTextNode(text) {
        const walker = document.createTreeWalker(document.body || document.documentElement, NodeFilter.SHOW_ELEMENT);
        let node = walker.nextNode();
        while (node) {
            if (node.textContent && node.textContent.indexOf(text) !== -1 && isVisible(node)) {
                return node;
            }
            node = walker.nextNode();
        }
        return null;
    }

    function isNativeFlowStillStuck() {
        return Boolean(findVisibleTextNode('Starting download'));
    }

    function isExpiredToastVisible() {
        return Boolean(findVisibleTextNode('This file is no longer available.'));
    }

    function isEligibleDownloadButton(button) {
        if (!(button instanceof HTMLButtonElement)) {
            return false;
        }
        if (!button.classList.contains('behavior-btn')) {
            return false;
        }
        const messageRoot = button.closest('[data-message-author-role="assistant"][data-message-id]');
        if (!messageRoot) {
            return false;
        }
        const label = (button.textContent || '').trim();
        if (!label) {
            return false;
        }
        const paragraph = button.closest('p');
        if (paragraph && paragraph.textContent && paragraph.textContent.indexOf('Download:') !== -1) {
            return true;
        }
        return /^[^\n\r]+\.[A-Za-z0-9]{1,10}$/.test(label);
    }

    function getDownloadInfoFromButton(button) {
        const messageRoot = button.closest('[data-message-author-role="assistant"][data-message-id]');
        if (!messageRoot) {
            return null;
        }
        const filename = sanitizeFilename((button.textContent || '').trim());
        const conversationId = getConversationId();
        const messageId = messageRoot.getAttribute('data-message-id');
        if (!conversationId || !messageId || !filename) {
            return null;
        }
        return {
            button: button,
            conversationId: conversationId,
            messageId: messageId,
            filename: filename,
            sandboxPath: buildSandboxPath(filename)
        };
    }

    async function requestDownloadMetadata(info) {
        const url = new URL('/backend-api/conversation/' + encodeURIComponent(info.conversationId) + '/interpreter/download', window.location.origin);
        url.searchParams.set('message_id', info.messageId);
        url.searchParams.set('sandbox_path', info.sandboxPath);

        const response = await window.fetch(url.toString(), {
            method: 'GET',
            credentials: 'include',
            headers: {
                'Accept': 'application/json'
            }
        });

        if (!response.ok) {
            throw new Error('interpreter/download HTTP ' + response.status);
        }

        const payload = await response.json();
        return payload;
    }

    async function fetchBlobAndSave(downloadUrl, preferredFilename) {
        const response = await window.fetch(downloadUrl, {
            method: 'GET',
            credentials: 'include'
        });

        if (!response.ok) {
            throw new Error('download URL HTTP ' + response.status);
        }

        const blob = await response.blob();
        const filename = sanitizeFilename(
            parseFilenameFromContentDisposition(response.headers.get('content-disposition')) || preferredFilename
        );

        const objectUrl = URL.createObjectURL(blob);
        try {
            const anchor = document.createElement('a');
            anchor.href = objectUrl;
            anchor.download = filename;
            anchor.rel = 'noopener';
            anchor.style.display = 'none';
            document.body.appendChild(anchor);
            anchor.click();
            document.body.removeChild(anchor);
        }
        finally {
            window.setTimeout(function () {
                URL.revokeObjectURL(objectUrl);
            }, 10 * 1000);
        }
    }

    async function runWorkaroundDownload(info, sourceLabel) {
        const payload = await requestDownloadMetadata(info);

        if (!payload || payload.status !== 'success' || !payload.download_url) {
            const errorCode = payload && payload.error_code ? payload.error_code : 'unknown_error';
            const errorType = payload && payload.error_type ? payload.error_type : 'unknown_type';
            throw new Error('download metadata error: ' + errorCode + ' / ' + errorType);
        }

        await fetchBlobAndSave(payload.download_url, payload.file_name || info.filename);

        const nextState = writeState({
            mode: 'workaround',
            lastBrokenAt: nowMs(),
            lastMessage: 'Workaround download succeeded for ' + info.filename + ' via ' + sourceLabel
        });

        console.info('[ChatGPT Download Fix] Workaround download succeeded:', {
            info: info,
            sourceLabel: sourceLabel,
            state: nextState
        });
    }

    let activeProbe = null;

    function clearProbe(expectedProbe) {
        if (activeProbe && (!expectedProbe || activeProbe === expectedProbe)) {
            activeProbe = null;
        }
    }

    function shouldProbeNativeFlow() {
        const state = readState();
        if (state.mode !== 'workaround') {
            return true;
        }
        return (nowMs() - state.lastProbeAt) >= CONFIG.probeIntervalMs;
    }

    function markNativeHealthy(info) {
        const nextState = writeState({
            mode: 'probe',
            lastProbeAt: nowMs(),
            lastHealthyAt: nowMs(),
            lastMessage: 'Native download flow looked healthy for ' + info.filename
        });
        console.info('[ChatGPT Download Fix] Native download flow appears healthy again:', {
            info: info,
            state: nextState
        });
        showToast('ChatGPT native download looks healthy', 'The workaround stayed out of the way. You can keep using it as a safety net, or disable it and test native downloads directly.');
    }

    function markNativeBroken(info) {
        const nextState = writeState({
            mode: 'workaround',
            lastProbeAt: nowMs(),
            lastBrokenAt: nowMs(),
            lastMessage: 'Native download flow still stuck for ' + info.filename
        });
        console.info('[ChatGPT Download Fix] Native download flow still looks broken:', {
            info: info,
            state: nextState
        });
        return nextState;
    }

    async function handleImmediateWorkaround(info) {
        try {
            showToast('ChatGPT Download Fix', 'Using workaround immediately for ' + info.filename + '.');
            await runWorkaroundDownload(info, 'immediate-workaround');
        }
        catch (error) {
            const message = String(error && error.message ? error.message : error);
            console.error('[ChatGPT Download Fix] Immediate workaround failed:', error);
            if (message.indexOf('file_not_found') !== -1) {
                showToast('File already gone', 'ChatGPT reported that ' + info.filename + ' is no longer available.');
                return;
            }
            showToast('Download workaround failed', message);
        }
    }

    function scheduleProbeEvaluation(probe) {
        window.setTimeout(async function () {
            if (!activeProbe || activeProbe !== probe) {
                return;
            }

            clearProbe(probe);

            if (isExpiredToastVisible()) {
                writeState({
                    lastProbeAt: nowMs(),
                    lastMessage: 'Native download reported file_not_found for ' + probe.info.filename
                });
                showToast('File already gone', 'ChatGPT reported that ' + probe.info.filename + ' is no longer available.');
                return;
            }

            if (!isNativeFlowStillStuck()) {
                markNativeHealthy(probe.info);
                return;
            }

            markNativeBroken(probe.info);
            showToast('ChatGPT download still stuck', 'Falling back to the local workaround for ' + probe.info.filename + '.');

            try {
                await runWorkaroundDownload(probe.info, 'probe-fallback');
            }
            catch (error) {
                const message = String(error && error.message ? error.message : error);
                console.error('[ChatGPT Download Fix] Probe fallback failed:', error);
                if (message.indexOf('file_not_found') !== -1) {
                    showToast('File already gone', 'ChatGPT reported that ' + probe.info.filename + ' is no longer available.');
                    return;
                }
                showToast('Download workaround failed', message);
            }
        }, CONFIG.probeWaitMs);
    }

    function handleClick(event) {
        const button = event.target instanceof Element ? event.target.closest('button') : null;
        if (!button || !isEligibleDownloadButton(button)) {
            return;
        }

        const info = getDownloadInfoFromButton(button);
        if (!info) {
            return;
        }

        const state = readState();
        const shouldProbe = shouldProbeNativeFlow();

        if (!shouldProbe && state.mode === 'workaround') {
            event.preventDefault();
            event.stopPropagation();
            void handleImmediateWorkaround(info);
            return;
        }

        activeProbe = {
            info: info,
            startedAt: nowMs()
        };
        writeState({
            lastProbeAt: nowMs(),
            lastMessage: 'Running native probe for ' + info.filename
        });
        scheduleProbeEvaluation(activeProbe);
    }

    document.addEventListener('click', handleClick, true);

    window.addEventListener('load', function () {
        const state = readState();
        console.info('[ChatGPT Download Fix] Loaded:', state);
        if (state.mode === 'workaround') {
            showToast('ChatGPT Download Fix active', 'Workaround mode is currently enabled. The script will probe the native path again after the cooldown window.');
        }
    });
})();
