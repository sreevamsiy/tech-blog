resource "aws_glue_catalog_database" "cloudfront_logs" {
  name        = var.athena_database_name
  description = "Athena database for CloudFront access logs"
}

resource "aws_glue_catalog_table" "cloudfront_standard_logs" {
  name          = var.athena_cloudfront_table_name
  database_name = aws_glue_catalog_database.cloudfront_logs.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL                 = "TRUE"
    "skip.header.line.count" = "2"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.cloudfront_logs.bucket}/${var.cloudfront_logs_prefix}"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"

      parameters = {
        "field.delim"          = "\t"
        "serialization.format" = "\t"
      }
    }

    columns {
      name = "date"
      type = "date"
    }

    columns {
      name = "time"
      type = "string"
    }

    columns {
      name = "x_edge_location"
      type = "string"
    }

    columns {
      name = "sc_bytes"
      type = "bigint"
    }

    columns {
      name = "c_ip"
      type = "string"
    }

    columns {
      name = "cs_method"
      type = "string"
    }

    columns {
      name = "cs_host"
      type = "string"
    }

    columns {
      name = "cs_uri_stem"
      type = "string"
    }

    columns {
      name = "sc_status"
      type = "int"
    }

    columns {
      name = "cs_referrer"
      type = "string"
    }

    columns {
      name = "cs_user_agent"
      type = "string"
    }

    columns {
      name = "cs_uri_query"
      type = "string"
    }

    columns {
      name = "cs_cookie"
      type = "string"
    }

    columns {
      name = "x_edge_result_type"
      type = "string"
    }

    columns {
      name = "x_edge_request_id"
      type = "string"
    }

    columns {
      name = "x_host_header"
      type = "string"
    }

    columns {
      name = "cs_protocol"
      type = "string"
    }

    columns {
      name = "cs_bytes"
      type = "bigint"
    }

    columns {
      name = "time_taken"
      type = "float"
    }

    columns {
      name = "x_forwarded_for"
      type = "string"
    }

    columns {
      name = "ssl_protocol"
      type = "string"
    }

    columns {
      name = "ssl_cipher"
      type = "string"
    }

    columns {
      name = "x_edge_response_result_type"
      type = "string"
    }

    columns {
      name = "cs_protocol_version"
      type = "string"
    }

    columns {
      name = "fle_status"
      type = "string"
    }

    columns {
      name = "fle_encrypted_fields"
      type = "int"
    }

    columns {
      name = "c_port"
      type = "int"
    }

    columns {
      name = "time_to_first_byte"
      type = "float"
    }

    columns {
      name = "x_edge_detailed_result_type"
      type = "string"
    }

    columns {
      name = "sc_content_type"
      type = "string"
    }

    columns {
      name = "sc_content_len"
      type = "bigint"
    }

    columns {
      name = "sc_range_start"
      type = "bigint"
    }

    columns {
      name = "sc_range_end"
      type = "bigint"
    }
  }
}

resource "aws_athena_workgroup" "cloudfront_logs" {
  name        = var.athena_workgroup_name
  description = "Athena workgroup for CloudFront access log analysis"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.cloudfront_logs.bucket}/${var.athena_results_prefix}"
    }
  }

  tags = {
    Name        = var.athena_workgroup_name
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_athena_named_query" "top_pages" {
  name        = "cloudfront-top-pages"
  database    = aws_glue_catalog_database.cloudfront_logs.name
  workgroup   = aws_athena_workgroup.cloudfront_logs.name
  description = "Top requested pages by request count"
  query       = <<-SQL
SELECT
  cs_uri_stem,
  count(*) AS requests,
  sum(sc_bytes) AS bytes_served
FROM ${aws_glue_catalog_database.cloudfront_logs.name}.${aws_glue_catalog_table.cloudfront_standard_logs.name}
WHERE "date" >= current_date - interval '7' day
GROUP BY cs_uri_stem
ORDER BY requests DESC
LIMIT 20;
SQL
}

resource "aws_athena_named_query" "errors_by_path" {
  name        = "cloudfront-errors-by-path"
  database    = aws_glue_catalog_database.cloudfront_logs.name
  workgroup   = aws_athena_workgroup.cloudfront_logs.name
  description = "4xx and 5xx responses grouped by path and status"
  query       = <<-SQL
SELECT
  sc_status,
  cs_uri_stem,
  count(*) AS requests
FROM ${aws_glue_catalog_database.cloudfront_logs.name}.${aws_glue_catalog_table.cloudfront_standard_logs.name}
WHERE "date" >= current_date - interval '7' day
  AND sc_status >= 400
GROUP BY sc_status, cs_uri_stem
ORDER BY requests DESC
LIMIT 50;
SQL
}

resource "aws_athena_named_query" "cache_results" {
  name        = "cloudfront-cache-results"
  database    = aws_glue_catalog_database.cloudfront_logs.name
  workgroup   = aws_athena_workgroup.cloudfront_logs.name
  description = "CloudFront cache result breakdown"
  query       = <<-SQL
SELECT
  x_edge_result_type,
  count(*) AS requests,
  round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS percentage
FROM ${aws_glue_catalog_database.cloudfront_logs.name}.${aws_glue_catalog_table.cloudfront_standard_logs.name}
WHERE "date" >= current_date - interval '7' day
GROUP BY x_edge_result_type
ORDER BY requests DESC;
SQL
}

resource "aws_athena_named_query" "traffic_by_day" {
  name        = "cloudfront-traffic-by-day"
  database    = aws_glue_catalog_database.cloudfront_logs.name
  workgroup   = aws_athena_workgroup.cloudfront_logs.name
  description = "Daily request and bandwidth trend"
  query       = <<-SQL
SELECT
  "date",
  count(*) AS requests,
  round(sum(sc_bytes) / 1024.0 / 1024.0, 2) AS mb_served
FROM ${aws_glue_catalog_database.cloudfront_logs.name}.${aws_glue_catalog_table.cloudfront_standard_logs.name}
GROUP BY "date"
ORDER BY "date" DESC
LIMIT 30;
SQL
}

resource "aws_athena_named_query" "top_visitor_ips" {
  name        = "cloudfront-top-visitor-ips"
  database    = aws_glue_catalog_database.cloudfront_logs.name
  workgroup   = aws_athena_workgroup.cloudfront_logs.name
  description = "Top client IPs by request volume"
  query       = <<-SQL
SELECT
  c_ip,
  count(*) AS requests,
  count(DISTINCT cs_uri_stem) AS unique_paths,
  min("date") AS first_seen,
  max("date") AS last_seen
FROM ${aws_glue_catalog_database.cloudfront_logs.name}.${aws_glue_catalog_table.cloudfront_standard_logs.name}
WHERE "date" >= current_date - interval '7' day
GROUP BY c_ip
ORDER BY requests DESC
LIMIT 25;
SQL
}

resource "aws_athena_named_query" "top_referrers" {
  name        = "cloudfront-top-referrers"
  database    = aws_glue_catalog_database.cloudfront_logs.name
  workgroup   = aws_athena_workgroup.cloudfront_logs.name
  description = "Top external referrers"
  query       = <<-SQL
SELECT
  cs_referrer,
  count(*) AS requests
FROM ${aws_glue_catalog_database.cloudfront_logs.name}.${aws_glue_catalog_table.cloudfront_standard_logs.name}
WHERE "date" >= current_date - interval '7' day
  AND cs_referrer <> '-'
GROUP BY cs_referrer
ORDER BY requests DESC
LIMIT 25;
SQL
}

resource "aws_athena_named_query" "top_user_agents" {
  name        = "cloudfront-top-user-agents"
  database    = aws_glue_catalog_database.cloudfront_logs.name
  workgroup   = aws_athena_workgroup.cloudfront_logs.name
  description = "Top user agents by request volume"
  query       = <<-SQL
SELECT
  cs_user_agent,
  count(*) AS requests
FROM ${aws_glue_catalog_database.cloudfront_logs.name}.${aws_glue_catalog_table.cloudfront_standard_logs.name}
WHERE "date" >= current_date - interval '7' day
GROUP BY cs_user_agent
ORDER BY requests DESC
LIMIT 25;
SQL
}

resource "aws_athena_named_query" "post_views_by_ip" {
  name        = "cloudfront-post-views-by-ip"
  database    = aws_glue_catalog_database.cloudfront_logs.name
  workgroup   = aws_athena_workgroup.cloudfront_logs.name
  description = "Client IPs grouped by blog post path"
  query       = <<-SQL
SELECT
  c_ip,
  cs_uri_stem,
  count(*) AS requests,
  max(concat(cast("date" AS varchar), ' ', time)) AS last_seen
FROM ${aws_glue_catalog_database.cloudfront_logs.name}.${aws_glue_catalog_table.cloudfront_standard_logs.name}
WHERE "date" >= current_date - interval '7' day
  AND cs_uri_stem LIKE '/posts/%'
GROUP BY c_ip, cs_uri_stem
ORDER BY last_seen DESC, requests DESC
LIMIT 50;
SQL
}

resource "aws_athena_named_query" "human_readable_requests" {
  name        = "cloudfront-human-readable-requests"
  database    = aws_glue_catalog_database.cloudfront_logs.name
  workgroup   = aws_athena_workgroup.cloudfront_logs.name
  description = "Requests excluding common static asset paths"
  query       = <<-SQL
SELECT
  c_ip,
  cs_uri_stem,
  cs_user_agent,
  cs_referrer,
  count(*) AS requests
FROM ${aws_glue_catalog_database.cloudfront_logs.name}.${aws_glue_catalog_table.cloudfront_standard_logs.name}
WHERE "date" >= current_date - interval '7' day
  AND cs_uri_stem NOT LIKE '%.css'
  AND cs_uri_stem NOT LIKE '%.js'
  AND cs_uri_stem NOT LIKE '%.png'
  AND cs_uri_stem NOT LIKE '%.svg'
  AND cs_uri_stem NOT LIKE '%.xml'
GROUP BY c_ip, cs_uri_stem, cs_user_agent, cs_referrer
ORDER BY requests DESC
LIMIT 50;
SQL
}

resource "aws_athena_named_query" "browser_requests_by_city_last_24h" {
  name        = "cloudfront-browser-requests-by-city-last-24h"
  database    = aws_glue_catalog_database.cloudfront_logs.name
  workgroup   = aws_athena_workgroup.cloudfront_logs.name
  description = "Browser-like requests grouped by country and city for the last 24 hours"
  query       = <<-SQL
SELECT
  l.country_name,
  l.city_name,
  COUNT(*) AS requests
FROM cloudfront_standard_logs c
JOIN geo_ipv4 g
  ON contains(g.network, CAST(c.c_ip AS IPADDRESS))
JOIN geo_locations l
  ON CAST(g.geoname_id AS BIGINT) = l.geoname_id
WHERE CAST(CONCAT(CAST(c.date AS VARCHAR), ' ', c.time) AS TIMESTAMP) >= current_timestamp - INTERVAL '24' HOUR
  AND (
    c.cs_user_agent LIKE '%Chrome%'
    OR c.cs_user_agent LIKE '%Safari%'
    OR c.cs_user_agent LIKE '%Firefox%'
  )
GROUP BY l.country_name, l.city_name
ORDER BY requests DESC;
SQL
}
