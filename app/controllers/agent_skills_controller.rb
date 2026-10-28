require "digest"

# Machine-readable discovery must work without the public layout, browser gate,
# session locale, or HTML/Markdown negotiation in ApplicationController.
class AgentSkillsController < ActionController::Base
  SKILL_PATH = Rails.root.join("config/agent_skills/sleep-puzzle-guide/SKILL.md")
  DESCRIPTION = "Find Sleep Puzzle's consultations, audio programmes, bedtime stories, and public information in Polish or English."

  before_action :set_discovery_headers

  def index
    render json: {
      "$schema" => "https://schemas.agentskills.io/discovery/0.2.0/schema.json",
      "skills" => [ {
        name: "sleep-puzzle-guide",
        type: "skill-md",
        description: DESCRIPTION,
        url: "/.well-known/agent-skills/sleep-puzzle-guide/SKILL.md",
        digest: "sha256:#{Digest::SHA256.hexdigest(File.binread(SKILL_PATH))}"
      } ]
    }
  end

  def show
    send_data File.binread(SKILL_PATH), type: "text/markdown; charset=utf-8", disposition: "inline"
  end

  private

  def set_discovery_headers
    expires_in 5.minutes, public: true
    response.set_header("Access-Control-Allow-Origin", "*")
  end
end
