import React from 'react';
import PageHeader from '../components/PageHeader';
import { Leader } from '../components/Text';
import { Col, Row, Button, Card } from 'react-bootstrap';
import { Link, useHistory } from 'react-router-dom';
import { connect } from 'react-redux';
import store from '../store';
import { api_fetch_local_dispos } from '../api';
import { ch_join_dispo } from '../socket';
import { convertDateTime, getMyLocation } from '../util';

function None({session}) {

  console.log("session is", session);

  return (
    <div>
      <h2>{"None found in your location"}</h2>
      {session?.user_id &&
        <div className="my-5">
          <Link to="/dispo/new">
            <Button variant="primary" size="lg">{"Create one"}</Button>
          </Link>
      </div>}
    </div>
  );
}

function Discover({session, location, local_dispos, dispatch}) {

  console.log("rerender w location", location)
  let history = useHistory();

  function handle_join(id) {
    console.log("Join clicked")
    let redirect = () => {
      history.replace(`/dispo/${id}`);
      dispatch({ type: "success/setone", data: "Dispo joined" });
    };
    ch_join_dispo(id, redirect);
  }

  React.useEffect(() => {
    // get my location on mount
    if (!location.lat || !location.lng) {
      getMyLocation(dispatch);
    }
  }, []);

  React.useEffect(() => {
    if (location.lat && location.lng) {
      console.log("fetch with location", location)
      api_fetch_local_dispos(location);
    }
  }, [location]);

  return (
    <div>
      <PageHeader />
      <Col className="w-50 mx-auto">
        <div className="mb-3">
          <Row className="d-flex flex-row justify-content-between align-items-center">
            <Col><Leader>{"Around me"}</Leader></Col>
            <Col xs="auto">
              <Button
                variant="primary"
                onClick={() => api_fetch_local_dispos(location)}>
                {"Refresh"}
              </Button>
            </Col>
          </Row>
          {location.lat && <small>{`${location.lat}, ${location.lng}`}</small>}
        </div>
        <div>
          {local_dispos.length > 0 ?
            local_dispos.map((dispo, i) =>
              <Row key={`disp-${dispo.id}`}>
                <Card
                  className="p-4 mb-3">
                  <Card.Title>{dispo.name}</Card.Title>
                  <Card.Subtitle className="mb-3 text-muted">
                    {convertDateTime(dispo.created)}
                  </Card.Subtitle>
                  {session?.user_id &&
                    (dispo.is_public ?
                      <Button variant="primary" onClick={() => handle_join(dispo.id)}>
                        {"Join"}
                      </Button> :
                      <Row className="align-items-center">
                        <Col>
                          <Link
                            to={`/dispo/${dispo.id}/auth`}
                            size="sm"
                            className="btn btn-outline-primary">
                            {"Join"}
                          </Link>
                        </Col>
                        <Col><small>{"Passphrase required"}</small></Col>
                      </Row>)}
                  </Card>
              </Row>) :
            location.lat && location.lng && <None session={session} />}
        </div>
      </Col>
    </div>
  );

}

function state_to_props({session, location, local_dispos}) {
  return {session, location, local_dispos};
}

// Remember, you get `dispatch` for free as a prop when you do this
export default connect(state_to_props)(Discover);
