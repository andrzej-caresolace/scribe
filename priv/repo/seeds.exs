# Script for populating the database with mock meeting data.
# Run with: mix run priv/repo/seeds.exs
# Or in production: fly ssh console -C "/app/bin/social_scribe eval 'SocialScribe.Release.seed()'"

import Ecto.Query

alias SocialScribe.Repo
alias SocialScribe.Accounts.{User, UserCredential}
alias SocialScribe.Calendar.CalendarEvent
alias SocialScribe.Bots.RecallBot
alias SocialScribe.Meetings.{Meeting, MeetingTranscript, MeetingParticipant}

# Find the first user (the one who logged in via Google OAuth)
user = Repo.one!(from u in User, order_by: [asc: u.id], limit: 1)
IO.puts("Seeding data for user: #{user.email} (id: #{user.id})")

# Find or create a credential for calendar events
credential =
  Repo.one(from c in UserCredential, where: c.user_id == ^user.id, limit: 1) ||
    Repo.insert!(%UserCredential{
      provider: "google",
      uid: "seed-uid-#{System.unique_integer([:positive])}",
      token: "seed-token",
      refresh_token: "seed-refresh",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      user_id: user.id,
      email: user.email
    })

IO.puts("Using credential: #{credential.provider} (id: #{credential.id})")

# Delete old seed data and re-create with correct format
old_seeds = Repo.all(from m in Meeting, where: like(m.title, "Q1 Product Strategy%") or like(m.title, "Sales Pipeline%") or like(m.title, "Engineering Sprint%") or like(m.title, "Customer Onboarding%") or like(m.title, "Investor Update%"))

if Enum.any?(old_seeds) do
  IO.puts("Removing #{length(old_seeds)} old seed meetings...")
  for m <- old_seeds do
    # Delete dependents first
    Repo.delete_all(from t in MeetingTranscript, where: t.meeting_id == ^m.id)
    Repo.delete_all(from p in MeetingParticipant, where: p.meeting_id == ^m.id)
    Repo.delete(m)
  end
end

existing = false

if existing do
  IO.puts("Seed meetings already exist — skipping.")
else
  now = DateTime.utc_now() |> DateTime.truncate(:second)

  meetings_data = [
    %{
      title: "Q1 Product Strategy Review",
      summary: "Q1 Product Strategy Review — Quarterly Planning",
      recorded_at: DateTime.add(now, -2 * 86400, :second),
      duration: 2700,
      meeting_url: "https://meet.google.com/abc-defg-hij",
      participants: [
        %{name: "Andrzej Grabowski", is_host: true},
        %{name: "Sophie Müller", is_host: false},
        %{name: "Marco Bianchi", is_host: false},
        %{name: "Elena Johansson", is_host: false}
      ],
      transcript: [
        %{"speaker" => "Andrzej Grabowski", "words" => "Welcome everyone to our Q1 strategy review. Let's start by looking at where we stand on our product roadmap and key metrics."},
        %{"speaker" => "Sophie Müller", "words" => "Thanks Andrzej. So our user engagement is up 23% quarter over quarter. The new onboarding flow we shipped in December is really paying off. Retention at day-30 improved from 41% to 58%."},
        %{"speaker" => "Marco Bianchi", "words" => "That's great to hear. On the engineering side, we've reduced our average deploy time to under 15 minutes and our incident rate dropped by 40%. The team has been really focused on reliability."},
        %{"speaker" => "Elena Johansson", "words" => "From a design perspective, I want to flag that our mobile experience still needs work. User satisfaction scores on mobile are 3.2 versus 4.1 on desktop. I think we should prioritize the mobile redesign this quarter."},
        %{"speaker" => "Andrzej Grabowski", "words" => "Good point Elena. Let's make that a top priority. Sophie, can you put together a proposal for the mobile improvements with estimated impact on our core metrics?"},
        %{"speaker" => "Sophie Müller", "words" => "Absolutely. I'll have that ready by end of week. I also want to discuss the enterprise tier — we've had 12 inbound requests this month from companies with 500+ employees."},
        %{"speaker" => "Marco Bianchi", "words" => "We'd need to build out SSO integration, audit logging, and role-based access control for enterprise. I'd estimate about 6-8 weeks of engineering effort."},
        %{"speaker" => "Andrzej Grabowski", "words" => "Let's scope that properly. Marco, can you create technical specs for the enterprise features? And let's reconvene next week to finalize our Q1 priorities."},
        %{"speaker" => "Elena Johansson", "words" => "I'll prepare wireframes for both the mobile redesign and the enterprise admin dashboard so we can discuss them together."},
        %{"speaker" => "Andrzej Grabowski", "words" => "Perfect. Great meeting everyone. Let's keep the momentum going this quarter."}
      ]
    },
    %{
      title: "Sales Pipeline Review with Marketing",
      summary: "Weekly Sales + Marketing Sync",
      recorded_at: DateTime.add(now, -1 * 86400, :second),
      duration: 1800,
      meeting_url: "https://meet.google.com/klm-nopq-rst",
      participants: [
        %{name: "Andrzej Grabowski", is_host: true},
        %{name: "Isabelle Durand", is_host: false},
        %{name: "Lukas Schneider", is_host: false}
      ],
      transcript: [
        %{"speaker" => "Andrzej Grabowski", "words" => "Let's go through our pipeline. Isabelle, what's the latest on the enterprise leads?"},
        %{"speaker" => "Isabelle Durand", "words" => "We've got 8 qualified leads in the pipeline right now. Three are in the final negotiation stage — TechCorp, Meridian Health, and CloudBase. Combined ARR potential is about $340K."},
        %{"speaker" => "Lukas Schneider", "words" => "The content campaign we launched last month is generating great results. Our latest whitepaper on AI-powered workflows got 2,400 downloads and 180 demo requests."},
        %{"speaker" => "Andrzej Grabowski", "words" => "That's impressive conversion. What's our close rate looking like on those demo requests?"},
        %{"speaker" => "Isabelle Durand", "words" => "About 15% from demo to trial, then 40% from trial to paid. So roughly 6% end-to-end. We're working on improving the demo-to-trial handoff."},
        %{"speaker" => "Lukas Schneider", "words" => "I'm planning a webinar series for next month targeting mid-market companies. Topic will be 'Automating Your Sales Workflow with AI'. Should help warm up leads before the demo."},
        %{"speaker" => "Andrzej Grabowski", "words" => "Love it. Let's also get some customer testimonials for the landing page. Isabelle, can you reach out to our top 5 accounts for quotes?"},
        %{"speaker" => "Isabelle Durand", "words" => "Already on it. TechCorp and Meridian both agreed to do case studies. I'll follow up with the others this week."}
      ]
    },
    %{
      title: "Engineering Sprint Retrospective",
      summary: "Sprint 24 Retrospective",
      recorded_at: DateTime.add(now, -3 * 86400, :second),
      duration: 3600,
      meeting_url: "https://meet.google.com/uvw-xyza-bcd",
      participants: [
        %{name: "Marco Bianchi", is_host: true},
        %{name: "Andrzej Grabowski", is_host: false},
        %{name: "Katarina Novak", is_host: false},
        %{name: "Thomas Eriksson", is_host: false},
        %{name: "Anna Kowalska", is_host: false}
      ],
      transcript: [
        %{"speaker" => "Marco Bianchi", "words" => "Alright team, let's do our sprint retro. We shipped the new dashboard, the API v2 endpoints, and the notification system. What went well?"},
        %{"speaker" => "Katarina Novak", "words" => "The pair programming sessions were really productive. Thomas and I knocked out the entire notification system in 3 days, which we estimated would take a full week."},
        %{"speaker" => "Thomas Eriksson", "words" => "Agreed. Also, the new CI pipeline Marco set up saved us a ton of time. Builds went from 12 minutes to 4 minutes."},
        %{"speaker" => "Anna Kowalska", "words" => "On the dashboard side, having the design specs finalized early was a huge help. No back-and-forth this sprint, which was refreshing."},
        %{"speaker" => "Andrzej Grabowski", "words" => "What could we improve? I noticed we had a couple of late-breaking bugs that caused some weekend work."},
        %{"speaker" => "Marco Bianchi", "words" => "Yeah, we need better integration tests. The bugs were at the boundary between the API and the frontend. I propose we add end-to-end tests for critical flows."},
        %{"speaker" => "Katarina Novak", "words" => "I'd also like to see us do more code reviews. A few PRs went in with only one reviewer. We should require two approvals for anything touching core business logic."},
        %{"speaker" => "Thomas Eriksson", "words" => "Totally agree. Also, can we get a staging environment that mirrors production? Testing against dev doesn't catch the same issues."},
        %{"speaker" => "Marco Bianchi", "words" => "Good action items. Let me summarize: add E2E tests, require two PR approvals for core code, and set up a proper staging environment. I'll create tickets for all of these."},
        %{"speaker" => "Andrzej Grabowski", "words" => "Great retro everyone. Let's carry this energy into the next sprint."}
      ]
    },
    %{
      title: "Customer Onboarding — Meridian Health",
      summary: "Meridian Health Kickoff Meeting",
      recorded_at: DateTime.add(now, -5 * 86400, :second),
      duration: 2400,
      meeting_url: "https://meet.google.com/efg-hijk-lmn",
      participants: [
        %{name: "Andrzej Grabowski", is_host: true},
        %{name: "Isabelle Durand", is_host: false},
        %{name: "Dr. Heinrich Weber", is_host: false},
        %{name: "Pieter Van den Berg", is_host: false}
      ],
      transcript: [
        %{"speaker" => "Andrzej Grabowski", "words" => "Welcome Dr. Weber and Pieter. We're excited to get Meridian Health onboarded. Let me walk you through our implementation timeline."},
        %{"speaker" => "Dr. Heinrich Weber", "words" => "Thanks Andrzej. We're really looking forward to this. Our current workflow is very manual — our team spends about 20 hours a week just on data entry and follow-ups."},
        %{"speaker" => "Isabelle Durand", "words" => "That's exactly what we'll help automate. Based on our assessment, we can reduce that to about 3-4 hours with our AI-powered automation."},
        %{"speaker" => "Pieter Van den Berg", "words" => "That would be incredible. Our biggest pain point is the CRM updates after patient consultations. Can your system handle HIPAA-compliant data?"},
        %{"speaker" => "Andrzej Grabowski", "words" => "Absolutely. Our enterprise tier includes full HIPAA compliance, data encryption at rest and in transit, and we can sign a BAA. Let me share the security documentation."},
        %{"speaker" => "Dr. Heinrich Weber", "words" => "Perfect. And what about integration with our existing Salesforce instance? We've customized it quite a bit."},
        %{"speaker" => "Isabelle Durand", "words" => "We support custom Salesforce fields and objects. During the setup phase, we'll map your custom fields to our system. Usually takes about 2-3 days."},
        %{"speaker" => "Andrzej Grabowski", "words" => "So here's the timeline: Week 1 is integration setup, Week 2 is testing with your team, Week 3 is training sessions, and by Week 4 you'll be fully live. Sound good?"},
        %{"speaker" => "Pieter Van den Berg", "words" => "That's faster than we expected. Let's go ahead and get started. Can you send over the integration requirements?"},
        %{"speaker" => "Isabelle Durand", "words" => "I'll send those over today along with the BAA and security questionnaire. Welcome aboard!"}
      ]
    },
    %{
      title: "Investor Update — Series A Progress",
      summary: "Monthly Investor Update Call",
      recorded_at: DateTime.add(now, -7 * 86400, :second),
      duration: 1500,
      meeting_url: "https://meet.google.com/opq-rstu-vwx",
      participants: [
        %{name: "Andrzej Grabowski", is_host: true},
        %{name: "Sophie Müller", is_host: false},
        %{name: "Henrik Lindberg", is_host: false}
      ],
      transcript: [
        %{"speaker" => "Andrzej Grabowski", "words" => "Hi Henrik, thanks for joining our monthly update. We've had an exciting month. MRR grew 18% to $127K, and we closed 3 new enterprise accounts."},
        %{"speaker" => "Henrik Lindberg", "words" => "Those are strong numbers. What's driving the enterprise growth? Last month you mentioned it was mostly SMB."},
        %{"speaker" => "Sophie Müller", "words" => "We launched our enterprise tier in January and the response has been immediate. The AI meeting automation feature is a huge differentiator — no one else in the market does it as well."},
        %{"speaker" => "Andrzej Grabowski", "words" => "Our pipeline is also looking great. We have $500K in qualified enterprise opportunities for Q1. If we close even half of those, we'll hit our annual target ahead of schedule."},
        %{"speaker" => "Henrik Lindberg", "words" => "Impressive. What about the technical side? Any concerns about scaling?"},
        %{"speaker" => "Andrzej Grabowski", "words" => "We've invested heavily in infrastructure. Our platform handles 10x our current load in stress tests. We're also building out multi-region deployment for enterprise SLAs."},
        %{"speaker" => "Sophie Müller", "words" => "On the team side, we've grown to 15 people. We're hiring 3 more engineers and a VP of Sales this quarter. Burn rate is at $180K/month with 14 months of runway."},
        %{"speaker" => "Henrik Lindberg", "words" => "Sounds like you're in a great position. Let's schedule a deeper dive on the enterprise strategy next week. I might have some introductions for you."},
        %{"speaker" => "Andrzej Grabowski", "words" => "That would be fantastic. Thanks Henrik, talk to you next week."}
      ]
    }
  ]

  for data <- meetings_data do
    # 1. Create CalendarEvent
    {:ok, event} =
      Repo.insert(%CalendarEvent{
        google_event_id: "seed-#{System.unique_integer([:positive])}",
        summary: data.summary,
        html_link: "https://calendar.google.com/event?id=seed",
        status: "confirmed",
        start_time: DateTime.add(data.recorded_at, -300, :second),
        end_time: DateTime.add(data.recorded_at, data.duration, :second),
        user_id: user.id,
        user_credential_id: credential.id,
        record_meeting: true
      })

    # 2. Create RecallBot
    {:ok, bot} =
      Repo.insert(%RecallBot{
        recall_bot_id: "seed-bot-#{System.unique_integer([:positive])}",
        status: "done",
        meeting_url: data.meeting_url,
        user_id: user.id,
        calendar_event_id: event.id
      })

    # 3. Create Meeting
    {:ok, meeting} =
      Repo.insert(%Meeting{
        title: data.title,
        recorded_at: data.recorded_at,
        duration_seconds: data.duration,
        calendar_event_id: event.id,
        recall_bot_id: bot.id
      })

    # 4. Create MeetingTranscript
    # Format: content["data"] with each entry having "speaker" and "words" (list of %{"text" => "..."})
    formatted_transcript =
      Enum.map(data.transcript, fn seg ->
        words = seg["words"] |> String.split(" ") |> Enum.map(fn w -> %{"text" => w} end)
        %{"speaker" => seg["speaker"], "words" => words}
      end)

    {:ok, _transcript} =
      Repo.insert(%MeetingTranscript{
        content: %{"data" => formatted_transcript},
        language: "en",
        meeting_id: meeting.id
      })

    # 5. Create MeetingParticipants
    for {p, idx} <- Enum.with_index(data.participants) do
      Repo.insert!(%MeetingParticipant{
        recall_participant_id: "seed-participant-#{meeting.id}-#{idx}",
        name: p.name,
        is_host: p.is_host,
        meeting_id: meeting.id
      })
    end

    IO.puts("  ✓ Created meeting: #{data.title}")
  end

  IO.puts("\nDone! Created #{length(meetings_data)} mock meetings with transcripts and participants.")
end
