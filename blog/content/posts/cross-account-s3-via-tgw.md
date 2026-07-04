---
title: "Cross-Account, Cross-Region S3 Access Over Private Network Using Transit Gateway Peering"
date: 2026-07-04
draft: false
tags: ["aws", "transit-gateway", "s3", "vpc-endpoint", "platform-engineering", "networking"]
categories: ["Platform Engineering"]
description: "How we enabled private cross-account, cross-region S3 access by leveraging our hub-and-spoke Transit Gateway architecture, VPC Interface Endpoints, and PrivateLink — without any traffic leaving the AWS network."
---

I'm part of a platform engineering team responsible for shared resources such as Transit Gateways, ACM Private CA, KMS keys, and more. We operate a hub-and-spoke model with a few shared hub accounts and multiple spoke accounts belonging to various application teams.

Recently I worked on a request from an application team — let's call them App Team A — who are setting up their disaster recovery environment in `us-west-2` and need to access an S3 bucket owned by another application team, App Team B, which is in `us-east-1`. The data is sensitive and cannot leave the AWS network.

## The Constraints

Every service invoked from inside our VPCs goes through a VPC endpoint. This rules out both public S3 endpoints and our HTTP proxy, which we built to route traffic to a limited set of internet endpoints. Private-only, end to end.

## What Was Already in Place

Our hub-and-spoke model meant most of the heavy lifting was already done:

- The hub account has two shared Transit Gateways — one in `us-east-1` and one in `us-west-2`.
- Both TGWs are shared with App Team A and App Team B via **AWS Resource Access Manager (RAM)**.
- Each application team has already created VPC attachments to their respective regional TGWs.
- The two TGWs are peered across regions.

{{< figure src="/images/cross-account-s3-tgw-diagram.png" alt="Architecture diagram showing cross-account S3 access via Transit Gateway peering and VPC Interface Endpoint" caption="Cross-account, cross-region S3 access via Hub TGW peering and VPC Interface Endpoint" >}}

## What I Had to Do

With the foundation in place, my work came down to three things:

1. **Establish bidirectional routing** on both TGW route tables — so traffic from App Team A's VPC CIDR (`us-west-2`) is routed toward the East TGW peering attachment, and vice versa.

2. **Update subnet NACLs** at both ends to allow the relevant CIDRs — inbound and outbound — on TCP port 443.

3. **Update security group rules** at both ends — outbound on the source side and inbound on the S3 interface endpoint's security group in App Team B's VPC, scoped to App Team A's VPC CIDR.

## How the Traffic Flows

App Team A's application in `us-west-2` is configured to use the **VPC Endpoint-specific DNS hostname** of the S3 Interface Endpoint that lives in App Team B's VPC in `us-east-1`. The hostname takes the form:

```
<bucket-name>.vpce-xxxx-s3.s3.us-east-1.vpce.amazonaws.com
```

This resolves to the private IPs of the endpoint ENIs inside App Team B's VPC. The request then travels entirely over the AWS private network:

**Account A (us-west-2)**
1. Request hits the **TGW VPC Attachment (West)** in App Team A's VPC.

**Hub Account**

2. Forwarded to the **West Transit Gateway**.
3. Routed via the **peering attachment** to the East Transit Gateway.
4. Forwarded to the **TGW VPC Attachment (East)** pointing to App Team B's VPC.

**Account B (us-east-1)**

5. Traffic arrives at the **S3 Interface Endpoint** inside App Team B's VPC, which forwards the request to S3 over PrivateLink.

The response travels the same path in reverse.

## Closing Thoughts

Setting this up reinforced my appreciation for our hub-and-spoke architecture. What could have been a complex, multi-team networking problem was reduced to a handful of targeted changes — routing entries, NACL rules, and security group updates. The shared TGW infrastructure and RAM sharing meant no new gateways, no new peering relationships to negotiate, and no traffic touching the internet.

If your team is dealing with cross-account, cross-region data access with strict network isolation requirements, a centralized Transit Gateway hub is well worth the investment.
