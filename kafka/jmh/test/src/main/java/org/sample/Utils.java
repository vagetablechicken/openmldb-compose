package org.sample;

import com.google.api.client.http.ByteArrayContent;
import com.google.api.client.http.GenericUrl;
import com.google.api.client.http.HttpContent;
import com.google.api.client.http.HttpRequest;
import com.google.api.client.http.HttpRequestFactory;
import com.google.api.client.http.HttpResponse;
import com.google.api.client.http.HttpTransport;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.common.io.CharStreams;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.io.IOException;
import java.io.InputStreamReader;
import java.util.Iterator;
import java.util.Properties;
import java.util.stream.StreamSupport;

import org.testng.Assert;

/**
 * Utility class for various operations related to Kafka connectors and API server.
 */
public class Utils {
    static final HttpTransport HTTP_TRANSPORT = new NetHttpTransport();

    /**
     * Constructs the URL for a Kafka connector based on the provided properties and connector name.
     * If the URL is not specified in the properties, it defaults to "http://localhost:8083".
     *
     * @param properties   the properties containing the URL configuration
     * @param connectorName the name of the connector
     * @return the constructed URL for the Kafka connector
     */
    public static String kafkaConnectorUrl(Properties properties, String connectorName) {
        String url = properties.getProperty("connect.listeners");
        if (url == null || url.isEmpty()) {
            url = "http://localhost:8083";
        }
        // default is 8083
        return url + "/connectors/" + connectorName;
    }

    /**
     * Creates a Kafka connector using the provided connector URL and configuration.
     *
     * @param connectorUrl the URL of the Kafka connector
     * @param config       the configuration for the Kafka connector
     * @return the response from the connector creation request
     * @throws IOException if an I/O error occurs during the request
     */
    public static String kafkaConnectorCreate(String connectorUrl, String config) throws IOException {
        HttpRequestFactory requestFactory = HTTP_TRANSPORT.createRequestFactory();
        HttpContent content = ByteArrayContent.fromString("application/json", config);
        HttpRequest request = requestFactory.buildPostRequest(new GenericUrl(connectorUrl), content);
        HttpResponse response = request.execute();
        // TODO check response.getStatusMessage());
        return CharStreams.toString(new InputStreamReader(response.getContent()));
    }

    /**
     * Deletes a Kafka connector using the provided connector URL.
     *
     * @param connectorUrl the URL of the Kafka connector
     * @return the response from the connector deletion request
     * @throws IOException if an I/O error occurs during the request
     */
    public static String kafkaConnectorDelete(String connectorUrl) throws IOException {
        HttpRequestFactory requestFactory = HTTP_TRANSPORT.createRequestFactory();
        HttpRequest request = requestFactory.buildDeleteRequest(new GenericUrl(connectorUrl));
        HttpResponse response = request.execute();
        // TODO check response.getStatusMessage());
        return CharStreams.toString(new InputStreamReader(response.getContent()));
    }

    /**
     * Updates a Kafka connector using the provided connector URL and configuration.
     *
     * @param connectorUrl the URL of the Kafka connector
     * @param config       the updated configuration for the Kafka connector
     * @return the response from the connector update request
     * @throws IOException if an I/O error occurs during the request
     */
    public static String kafkaConnectorUpdate(String connectorUrl, String config) throws IOException {
        HttpRequestFactory requestFactory = HTTP_TRANSPORT.createRequestFactory();
        HttpContent content = ByteArrayContent.fromString("application/json", config);
        HttpRequest request = requestFactory.buildPutRequest(new GenericUrl(connectorUrl), content);
        HttpResponse response = request.execute();
        // TODO check response.getStatusMessage());
        return CharStreams.toString(new InputStreamReader(response.getContent()));
    }

    /**
     * Executes a SQL query on the API server for the specified database.
     *
     * @param apiserverAddr the address of the API server
     * @param db            the name of the database
     * @param sql           the SQL query to execute
     * @return the response from the API server query request
     * @throws IOException if an I/O error occurs during the request
     */
    public static String apiserverQuery(String apiserverAddr, String db, String sql)
            throws IOException {
        // mode is online
        HttpRequestFactory requestFactory = HTTP_TRANSPORT.createRequestFactory();
        HttpContent content = ByteArrayContent.fromString(
                "application/json", "{\"sql\":\"" + sql + "\",\"mode\":\"online\"}");
        HttpRequest request = requestFactory.buildPostRequest(
                new GenericUrl("http://" + apiserverAddr + "/dbs/" + db), content);
        HttpResponse response = request.execute();
        // TODO check response.getStatusMessage());
        return CharStreams.toString(new InputStreamReader(response.getContent()));
    }

    /**
     * Sends a refresh request to the API server to update metadata.
     *
     * @param apiserverAddr the address of the API server
     * @return the response from the API server refresh request
     * @throws IOException if an I/O error occurs during the request
     */
    public static String apiserverRefresh(String apiserverAddr) throws IOException {
        HttpRequestFactory requestFactory = HTTP_TRANSPORT.createRequestFactory();
        HttpRequest request = requestFactory.buildPostRequest(
                new GenericUrl("http://" + apiserverAddr + "/refresh"), null);
        HttpResponse response = request.execute();
        // TODO check response.getStatusMessage());
        return CharStreams.toString(new InputStreamReader(response.getContent()));
    }

    /**
     * Checks if a table exists in the specified database on the API server.
     *
     * @param apiserverAddr the address of the API server
     * @param db            the name of the database
     * @param table         the name of the table
     * @return true if the table exists, false otherwise
     * @throws IOException if an I/O error occurs during the request
     */
    public static boolean apiserverTableExists(String apiserverAddr, String db, String table) throws IOException {
        HttpRequestFactory requestFactory = HTTP_TRANSPORT.createRequestFactory();
        HttpRequest request = requestFactory.buildGetRequest(
                new GenericUrl("http://" + apiserverAddr + "/dbs/" + db + "/tables"));
        HttpResponse response = request.execute();
        // TODO check response.getStatusMessage());
        String res = CharStreams.toString(new InputStreamReader(response.getContent()));
        // to json and check if table exists
        JsonObject resJson = JsonParser.parseString(res).getAsJsonObject();
        Assert.assertTrue(resJson.get("code").getAsInt() == 0, "fail to get table list: " + res);
        boolean find = false;
        Iterator<JsonElement> iter = resJson.get("tables").getAsJsonArray().iterator();
        Iterable<JsonElement> iterable = () -> iter;
        return StreamSupport.stream(iterable.spliterator(), false)
                .anyMatch(e -> e.getAsJsonObject().get("name").getAsString().equals(table));
    }
}
