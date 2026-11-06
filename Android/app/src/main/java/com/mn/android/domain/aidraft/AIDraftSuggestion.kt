package com.mn.android.domain.aidraft

/** One proposal of the model. */
data class AIDraftSuggestion(
    val id: String,
    val text: String,
    val rationale: String,
)
