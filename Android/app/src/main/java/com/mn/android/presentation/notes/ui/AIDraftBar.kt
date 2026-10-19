package com.mn.android.presentation.notes.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.RemoveCircle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.R
import com.mn.android.data.AIDraftSource
import com.mn.android.presentation.theme.ui.MnTheme

/**
 * Port of the iOS AI draft bar: the proposals the model returned, the accept
 * and remove actions, and the transfer of the accepted ones into the note.
 *
 * The bar is only rendered when there is something to show - a generation
 * running, a session with suggestions, or a failure worth naming.
 */
@Composable
internal fun AIDraftBar(
    isGenerating: Boolean,
    session: AIDraftSource.Session?,
    error: String?,
    onAccept: (AIDraftSource.Suggestion) -> Unit,
    onRemove: (AIDraftSource.Suggestion) -> Unit,
    onAcceptAll: () -> Unit,
    onTransfer: () -> Unit,
) {
    val hasContent = isGenerating || session != null || error != null
    if (!hasContent) return

    Column(
        Modifier
            .fillMaxWidth()
            .background(MnTheme.editorBackground, RoundedCornerShape(16.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        when {
            error == "freeQuotaExhausted" -> QuotaRow()
            error == "noProvider" -> NoProviderRow()
            isGenerating -> GeneratingRow()
            session != null -> SessionContent(
                session = session,
                onAccept = onAccept,
                onRemove = onRemove,
                onAcceptAll = onAcceptAll,
                onTransfer = onTransfer,
            )
            error != null -> ErrorRow()
        }
    }
}

// MARK: - Rows

@Composable
private fun GeneratingRow() {
    Row(verticalAlignment = Alignment.CenterVertically) {
        CircularProgressIndicator(
            modifier = Modifier.size(14.dp),
            strokeWidth = 2.dp,
            color = MnTheme.textSecondary,
        )
        Spacer(Modifier.width(8.dp))
        Text(
            stringResource(R.string.ai_draft_generating),
            fontSize = 12.sp,
            color = MnTheme.textSecondary,
        )
    }
}

@Composable
private fun QuotaRow() {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            Icons.Filled.Lock,
            contentDescription = null,
            tint = MnTheme.textSecondary,
            modifier = Modifier.size(14.dp),
        )
        Spacer(Modifier.width(8.dp))
        Text(
            stringResource(R.string.ai_draft_quota_exhausted),
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = MnTheme.textSecondary,
        )
    }
}

@Composable
private fun ErrorRow() {
    Text(
        stringResource(R.string.ai_draft_failed),
        fontSize = 12.sp,
        color = MnTheme.textSecondary,
    )
}

@Composable
private fun NoProviderRow() {
    Text(
        stringResource(R.string.ai_draft_no_provider),
        fontSize = 12.sp,
        color = MnTheme.textSecondary,
    )
}

@Composable
private fun SessionContent(
    session: AIDraftSource.Session,
    onAccept: (AIDraftSource.Suggestion) -> Unit,
    onRemove: (AIDraftSource.Suggestion) -> Unit,
    onAcceptAll: () -> Unit,
    onTransfer: () -> Unit,
) {
    val pending = session.pending
    if (pending.isNotEmpty()) {
        SectionLabel(
            stringResource(
                if (session.grounded) R.string.ai_draft_proposals else R.string.ai_draft_questions,
            ),
        )
        pending.forEach { suggestion ->
            SuggestionRow(suggestion, accepted = false, onAccept = onAccept, onRemove = onRemove)
        }
    }

    if (session.accepted.isNotEmpty()) {
        SectionLabel(stringResource(R.string.ai_draft_accepted))
        session.accepted.forEach { suggestion ->
            SuggestionRow(suggestion, accepted = true, onAccept = onAccept, onRemove = onRemove)
        }
    }

    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        if (pending.isNotEmpty()) {
            TextButton(onClick = onAcceptAll) {
                Text(
                    stringResource(R.string.ai_draft_accept_all),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MnTheme.textPrimary,
                )
            }
        }
        if (session.accepted.isNotEmpty()) {
            TextButton(onClick = onTransfer) {
                Text(
                    stringResource(R.string.ai_draft_transfer, session.accepted.size),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MnTheme.textPrimary,
                )
            }
        }
    }
}

@Composable
private fun SectionLabel(label: String) {
    Text(
        label,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        color = MnTheme.textSecondary,
    )
}

@Composable
private fun SuggestionRow(
    suggestion: AIDraftSource.Suggestion,
    accepted: Boolean,
    onAccept: (AIDraftSource.Suggestion) -> Unit,
    onRemove: (AIDraftSource.Suggestion) -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(
                if (accepted) MnTheme.accentColor.copy(alpha = 0.15f) else MnTheme.editorBackground,
                RoundedCornerShape(8.dp),
            )
            .padding(horizontal = 8.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            suggestion.text,
            fontSize = 12.sp,
            color = MnTheme.textPrimary,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (accepted) {
            TextButton(onClick = { onRemove(suggestion) }) {
                Icon(
                    Icons.Filled.RemoveCircle,
                    contentDescription = stringResource(R.string.ai_draft_remove),
                    tint = MnTheme.textSecondary,
                    modifier = Modifier.size(18.dp),
                )
            }
        } else {
            TextButton(onClick = { onAccept(suggestion) }) {
                Icon(
                    Icons.Filled.AddCircle,
                    contentDescription = stringResource(R.string.ai_draft_accept),
                    tint = MnTheme.textSecondary,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}
