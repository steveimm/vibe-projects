package id.steveimm.pocketpilot.protocol

/** Session lifecycle domain events. */
sealed interface SessionLifecycleEvent : AgentEvent

/** Task lifecycle domain events. */
sealed interface TaskLifecycleEvent : AgentEvent


/** Turn lifecycle domain events. */
sealed interface TurnDomainEvent : AgentEvent

/** Streaming output domain events. */
sealed interface StreamingDomainEvent : AgentEvent

/** Action proposal/execution domain events. */
sealed interface ActionDomainEvent : AgentEvent

/** Perception/capture domain events. */
sealed interface PerceptionDomainEvent : AgentEvent

/** Approval workflow domain events. */
sealed interface ApprovalDomainEvent : AgentEvent

/** ask_user workflow domain events. */
sealed interface AskUserDomainEvent : AgentEvent

/** Generic status line domain events. */
sealed interface StatusDomainEvent : AgentEvent
