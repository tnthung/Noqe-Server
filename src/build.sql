

-- extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- functions
CREATE OR REPLACE FUNCTION noqe_validate_name(text)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN $1 ~ '^[a-zA-Z_][a-zA-Z_\-0-9 ]*$';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION noqe_validate_email(text)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN $1 ~ '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION noqe_validate_status (UUID, JSONB)
RETURNS BOOLEAN AS $$ 
DECLARE
  i RECORD;
BEGIN
  FOR i IN SELECT
      status_id,
      array_length(states, 1) AS state_count
    FROM noqe_status
    WHERE $1 = project_id
  LOOP
    IF NOT ($2 ? i.status_id::TEXT) THEN
      RETURN FALSE;
    END IF;
    
    IF (($2->i.status_id::TEXT)::INTEGER < -1)
    OR (($2->i.status_id::TEXT)::INTEGER > (i.state_count-1)) THEN
      RETURN FALSE;
    END IF;
  END LOOP;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION noqe_create_status (UUID, TEXT, TEXT[])
RETURNS VOID AS $$
DECLARE
  s_id UUID;
BEGIN
  INSERT INTO noqe_status (project_id, name, states) 
  VALUES ($1, $2, $3) RETURNING status_id INTO s_id;

  UPDATE noqe_todo 
    SET status = status || ('{"' || s_id::TEXT || '": -1}')::JSONB
    WHERE project_id = $1;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION noqe_delete_status (UUID, TEXT)
RETURNS VOID AS $$
DECLARE
  s_id UUID;
BEGIN
  DELETE FROM noqe_status
    WHERE project_id=$1 AND name=$2 
    RETURNING status_id INTO s_id;
  
  UPDATE noqe_todo 
    SET status = status - s_id::TEXT
    WHERE project_id = $1;
END;
$$ LANGUAGE plpgsql;


-- user
CREATE TABLE IF NOT EXISTS noqe_user (
  -- PKs
  user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Fields
  name       TEXT NOT NULL,
  email      TEXT NOT NULL UNIQUE,
  passhash   TEXT NOT NULL,
  avatar_url TEXT,

  -- Constraints
  CONSTRAINT valid_name  CHECK (noqe_validate_name (name )),
  CONSTRAINT valid_email CHECK (noqe_validate_email(email))
);


-- org
CREATE TABLE IF NOT EXISTS noqe_org (
  -- PKs
  org_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- FKs
  owner_id UUID NOT NULL REFERENCES noqe_user (user_id)
    ON DELETE CASCADE ON UPDATE CASCADE,

  -- Fields
  name TEXT NOT NULL,

  -- Constraints
  CONSTRAINT valid_name CHECK  (noqe_validate_name(name)),
  CONSTRAINT unique_org UNIQUE (name, owner_id)
);


-- role
CREATE TABLE IF NOT EXISTS noqe_role (
  -- PKs
  role_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- FKs
  org_id UUID NOT NULL REFERENCES noqe_org (org_id)
    ON DELETE CASCADE ON UPDATE CASCADE,

  -- Fields
  name       TEXT  NOT NULL,
  permission JSONB NOT NULL,

  -- Constraints
  CONSTRAINT valid_name  CHECK  (noqe_validate_name(name)),
  CONSTRAINT unique_role UNIQUE (name, org_id)
);


-- enrollment
CREATE TABLE IF NOT EXISTS noqe_enrollment (
  -- PKs
  enrollment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- FKs
  user_id UUID NOT NULL REFERENCES noqe_user (user_id) 
    ON DELETE CASCADE ON UPDATE CASCADE,
    
  role_id UUID NOT NULL REFERENCES noqe_role (role_id) 
    ON DELETE CASCADE ON UPDATE CASCADE,

  -- fields
  permission JSONB NOT NULL,

  -- constraints
  CONSTRAINT unique_enrollment UNIQUE (user_id, role_id)
);


-- project
CREATE TABLE IF NOT EXISTS noqe_project (
  -- PKs
  project_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- FKs
  org_id UUID NOT NULL REFERENCES noqe_org (org_id) 
    ON DELETE CASCADE ON UPDATE CASCADE,

  -- fields
  name        TEXT NOT NULL,
  description TEXT,

  -- constraints
  CONSTRAINT valid_name     CHECK  (noqe_validate_name(name)),
  CONSTRAINT unique_project UNIQUE (name, org_id)
);


-- milestone
CREATE TABLE IF NOT EXISTS noqe_milestone (
  -- PKs
  milestone_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- FKs
  org_id UUID NOT NULL REFERENCES noqe_org (org_id) 
    ON DELETE CASCADE ON UPDATE CASCADE,

  -- fields
  name        TEXT NOT NULL,
  description TEXT,

  -- constraints
  CONSTRAINT valid_name       CHECK  (noqe_validate_name(name)),
  CONSTRAINT unique_milestone UNIQUE (name, org_id)
);


-- view
CREATE TABLE IF NOT EXISTS noqe_view (
  -- PKs
  view_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- FKs
  project_id UUID NOT NULL REFERENCES noqe_project (project_id)
    ON DELETE CASCADE ON UPDATE CASCADE,

  -- Fields
  name    TEXT   NOT NULL,
  type    TEXT   NOT NULL DEFAULT 'list',
  queries TEXT[] NOT NULL,

  -- Constraints
  CONSTRAINT valid_name CHECK (noqe_validate_name(name)),
  CONSTRAINT valid_type CHECK (type IN ('list', 'column', 'status'))
);


-- status
CREATE TABLE IF NOT EXISTS noqe_status (
  -- PKs
  status_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- FKs
  project_id UUID NOT NULL REFERENCES noqe_project (project_id) 
    ON DELETE CASCADE ON UPDATE CASCADE,

  -- fields
  name   TEXT   NOT NULL,
  states TEXT[] NOT NULL,

  -- constraints
  CONSTRAINT valid_name    CHECK  (noqe_validate_name(name)),
  CONSTRAINT valid_states  CHECK  (array_length(states, 1) > 1),
  CONSTRAINT unique_status UNIQUE (name, project_id)
);


-- tag
CREATE TABLE IF NOT EXISTS noqe_tag (
  -- PKs
  tag_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- FKs
  project_id UUID NOT NULL REFERENCES noqe_project (project_id) 
    ON DELETE CASCADE ON UPDATE CASCADE,

  -- fields
  name  TEXT    NOT NULL,
  color INTEGER NOT NULL,

  -- constraints
  CONSTRAINT valid_name  CHECK  (noqe_validate_name(name)),
  CONSTRAINT valid_color CHECK  (color >= 0 AND color < 16777216),
  CONSTRAINT unique_tag  UNIQUE (name, project_id)
);


-- todo
CREATE TABLE IF NOT EXISTS noqe_todo (
  -- PKs
  todo_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- FKs
  project_id UUID NOT NULL REFERENCES noqe_project (project_id) 
    ON DELETE CASCADE ON UPDATE CASCADE,
    
  milestone_id UUID REFERENCES noqe_milestone (milestone_id) 
    ON DELETE CASCADE ON UPDATE CASCADE,

  -- fields
  title       TEXT  NOT NULL,
  status      JSONB NOT NULL,
  description TEXT,

  -- constraints
  CONSTRAINT valid_status CHECK (noqe_validate_status(project_id, status))
);


-- tag assignment
CREATE TABLE IF NOT EXISTS noqe_tag_assignment (
  -- PKs
  tag_assignment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- FKs
  tag_id UUID NOT NULL REFERENCES noqe_tag (tag_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
    
  todo_id UUID NOT NULL REFERENCES noqe_todo (todo_id)
    ON DELETE CASCADE ON UPDATE CASCADE,

  -- constraints
  CONSTRAINT unique_tag_assignment UNIQUE (tag_id, todo_id)
);
