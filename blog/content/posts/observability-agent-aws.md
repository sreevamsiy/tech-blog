---
title: "Observability Agent with React, AWS AgentCore, and Claude Sonnet"
date: 2026-07-10T00:00:00+05:30
description: "I moved my observability agent off a Mac Mini and onto AWS — React on S3, Cognito auth, and a Strands agent running on Bedrock AgentCore with Claude Sonnet."
draft: false
images:
  - "/images/observability-agent-aws/oagent-architecture.png"
---

I previously built an observability agent for my blog, sreevamsi.dev, running entirely on my Mac Mini — a Streamlit chat UI, a Strands agent running locally, and Amazon Nova Lite as the model (see {{< ref "observability-agent.md" >}}).

I've now deployed it on AWS.

## From Streamlit to a React SPA

I replaced Streamlit with a React single-page application hosted on S3, since Streamlit needs a long-running compute process to serve — which would cost more than a static site sitting behind CloudFront.

## Authentication with Cognito

For authentication I used Amazon Cognito, with a user pool that has exactly one user — me.

## The Agent on AgentCore

The Strands agent itself now runs on Bedrock AgentCore Runtime with Claude Sonnet 4.6 as the model. The agent has several tools backed by Athena, plus one that queries AWS Cost Explorer.

Here's an abridged version of the system prompt:

```python
SYSTEM_PROMPT = """
You are an observability assistant for sreevamsi.dev.

Your purpose is to help users understand blog traffic, reader behaviour,
content performance, visitor journeys, operational issues, and AWS costs
using the available analytics tools.

...
"""
```

Here's the agent definition:

```python
def create_agent():
    return Agent(
        model=model,
        system_prompt=SYSTEM_PROMPT,
        tools=[
            # Core traffic analytics
            top_referrers,
            top_4xx_errors,
            top_articles,
            traffic_metrics,
            geo_location_analysis,

            # ... reader behaviour, visitor investigation, and
            # content flow tools omitted for brevity ...

            # AWS costs
            aws_daily_cost,
        ],
    )
```

Here's the model definition:

```python
model = BedrockModel(
    model_id="us.anthropic.claude-sonnet-4-6",
    region_name="us-east-1",
    cache_config=CacheConfig(strategy="auto"),
    cache_tools=None,
    guardrail_id="<guardrail-id>",
    guardrail_version="1",
    guardrail_latest_message=True,
)
```

Here's one of the tool definitions:

```python
@tool
def top_referrers(days: int = 1):
    """
    Show the top traffic sources, excluding bots.

    Args:
        days: Number of days to look back (default 1).
    """
    return run_athena_query(QUERY_MAP["top_referrers"](days=days))
```

## Architecture

{{< screenshot src="/images/observability-agent-aws/oagent-architecture.png" alt="Architecture diagram showing React, CloudFront, Cognito, AgentCore, Bedrock, Athena, and Cost Explorer" >}}

## Request Flow

Here's the flow for each request:

1. The entrypoint script receives the payload from the React app and creates an agent instance.
2. The guardrail integrated with the model validates the user's input and blocks any prompt injection attempts.
3. Memory integrated with the agent retrieves the prior chat history and prepends it to the question.
4. The Strands agent loop is invoked, using the model to select and call the right tools. Throughout this, it emits telemetry to a Langfuse project.
5. The tool response is checked again by the guardrail and filtered.
6. A new event is written to memory containing both the user and assistant turns.
7. The response is presented to the user.

{{< screenshot src="/images/observability-agent-aws/agentcore-internals.png" alt="Detailed diagram of the AgentCore internal request flow, including memory read and write, guardrail checks, and telemetry" >}}

## The Agent in Action

{{< screenshot src="/images/observability-agent-aws/oagent-chat.png" alt="Screenshot of the deployed React chat interface answering a question" >}}

## What It Costs

Here's the cost breakdown for a typical day with two or three sessions:

{{< screenshot src="/images/observability-agent-aws/cost-typical-day.png" alt="AWS Cost Explorer breakdown for a typical day of agent usage" >}}

---

It feels good to have actually built an agent after reading and hearing so much about agentic AI.
