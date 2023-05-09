/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesDrainageOrDrinkingWater]    Script Date: 09/05/2023 13:01:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==========================================================================================================================================================================
-- Description: Function for Businees Rules "Drainage Or Drinking Water"  
--
-- Change History:
--	2019-10-29  Diomer Bedoya: Funtion created
--	2021-08-21	Sebastián Jaramillo: Se RN adiciona VivaAerobus
--	2021-11-03	Sebastián Jaramillo: Se incluye RN Contrato Nuevo SARPA
--	2021-11-10	Sebastián Jaramillo: Se incluye RN Atención AVA - SAI en BOG
--	2021-12-06	Sebastián Jaramillo: Nueva RN American Airlines	
--  2021-12-27  Amilkar Martínez: Se excluye Drenaje y Agua Potable en Pernocta cuando existe la actividad de Limpieza para SARPA
--	2022-01-31	Sebastián Jaramillo: Nueva RN Ultra Air
--	2022-04-13	Sebastián Jaramillo: Ajuste RN Regional Express en PNTA
--	2022-07-28	Sebastián Jaramillo: Se ajusta RN VivaColombia para indicar explícitamente servicios internacionales
--	2022-09-28	Sebastián Jaramillo: Se adicionan RN Arajet
--	2022-11-11	Sebastián Jaramillo: Se incluye RN para el cliente Aerolineas Argentinas
--	2023-02-13	Sebastián Jaramillo: Se configura nuevo contrato de Avianca 2023 "TAKE OFF 20230201" y Regional Express se integra como un "facturar a" más de Avianca
--	2023-04-20	Sebastián Jaramillo: Fusión TALMA-SAI BOGEX Incorporación RN AVA estaciones (BGA, MTR, PSO, IBE, NVA) Compañía: Avianca - Facturar a: SAI
-- ==========================================================================================================================================================================

--SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesDrainageOrDrinkingWater] (1533469,45,2,1,1,17,16,'2021-09-10')
--(1533469,45,2,1,1,17,16,'2021-09-10')
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesDrainageOrDrinkingWater](
	@ServiceHeaderId BIGINT,
	@AirportId INT,
	@ServiceTypeId INT,
	@CompanyId INT,
	@BillingToCompany INT,
	@DestinationId INT,
	@ActivityTypeId INT, -- 15 drenaje / 16 agua potable 
	@DateService DATE
)
--RETURNS @Result TABLE (ROW INT IDENTITY, cantidad FLOAT, ds_servicio NVARCHAR(50))
RETURNS @Result TABLE(ROW INT IDENTITY, StartHour DATETIME, EndHour DATETIME, AdditionalService BIT, AdditionalQuantity INT, AdditionalServiceName VARCHAR(150))
AS
BEGIN
	DECLARE	@ExtraText VARCHAR(50) = ''

	DECLARE @ServiceDetail AS CIOReglaNegocio.ServiceDetailType --TIPO DEFINIDO
	INSERT	@ServiceDetail
	SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
			CASE WHEN @ActivityTypeId = 15 THEN 'DRENAJE' WHEN  @ActivityTypeId = 16 THEN 'AGUA POTABLE' END,
			DS.FechaInicio, 
			DS.FechaFin, 
			DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) TotalTime, 
			ISNULL(DS.cantidad, 1) Quantity
	FROM	CIOServicios.DetalleServicio DS
	WHERE	DS.Activo = 1 AND
			DS.TipoActividadId = @ActivityTypeId AND --DRENAJE o AGUA POTABLE
			DS.EncabezadoServicioId = @ServiceHeaderId

	IF (SELECT SUM(cantidad) FROM @ServiceDetail) = 0 RETURN

	--AEROLINEAS ARGENTINAS / AEROLINEAS ARGENTINAS
	IF (@CompanyId=67 AND @BillingToCompany=67)
	BEGIN
		IF (@DateService >= '2022-11-01')
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)

			RETURN
		END
	END

	--ARAJET / ARAJET
	IF (@CompanyId=272 AND @BillingToCompany=272)
	BEGIN
		IF (@DateService >= '2022-09-15')
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)

			RETURN
		END
	END

	--ULTRA AIR / ULTRA AIR
	IF (@CompanyId=259 AND @BillingToCompany=259)
	BEGIN
		IF (@DateService >= '2022-02-20')
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)

			RETURN
		END
	END

	--AMERICAN AIRLINES / AMERICAN AIRLINES
	IF (@CompanyId=43 AND @BillingToCompany=43)
	BEGIN
		IF (@DateService >= '2021-12-04')
		BEGIN
			IF (@ActivityTypeId = 15) -- 15 drenaje
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
			END

			IF (@ActivityTypeId = 16) -- 16 agua potable
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
			END

			RETURN
		END
	END

	IF	(	(@CompanyId = 1 AND @BillingToCompany = 1) --AVIANCA S.A A AVIANCA S.A
		OR	(@CompanyId = 1 AND @BillingToCompany = 193) --AVIANCA S.A A REGIONAL EXPRESS
		OR	(@CompanyId = 42 AND @BillingToCompany = 1) --TACA A AVIANCA S.A.
		OR	(@CompanyId = 47 AND @BillingToCompany = 1) --AEROGAL S.A A AVIANCA S.A.
		)
	BEGIN
		IF (@DateService >= '2023-02-01')
		BEGIN
			IF (@ServiceTypeId IN(2,3,4)) --PNTA		
			BEGIN		
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)		
				RETURN		
			END

			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)		
			RETURN	
		END
	END

	IF (@CompanyId = 1 AND @BillingToCompany = 87) --AVIANCA A SAI
	BEGIN
		IF (@DateService >= '2023-04-19' AND @AirportId IN (11, 40, 47, 31, 43)) --BGA, MTR, PSO, IBE, NVA
		BEGIN
			IF (@ServiceTypeId IN(2,3,4)) --PNTA		
			BEGIN		
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)		
				RETURN		
			END

			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)		
			RETURN	
		END

		IF (@DateService >= '2021-10-27' AND @AirportId = 12) --BOG
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
			RETURN
		END
	END

	IF (@CompanyId = 193 AND @BillingToCompany = 1) --REGIONAL EXPRESS A AVIANCA		
	BEGIN		
	    IF (@ServiceTypeId IN(2,3,4)) --PNTA		
	    BEGIN		
	        INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)		
	        RETURN		
	    END

	    INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)		
	    RETURN		
	END
	
	IF (@CompanyId = 70 AND @BillingToCompany = 70 AND @DateService > '2020-01-01') --INTERJET
	BEGIN
		BEGIN	--2020-02-03 CORRECCION DE REGLA DE NEGOCIO QUE ESTABA ERRADA ABAJO COMENTADO COMO ESTABA
	        IF (@ServiceTypeId IN(2,3,4)) --PNTA		
	        BEGIN		
	            INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)		
	            RETURN		
	        END		
	        INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)		
	        RETURN		
	    END

		--  IF (@ServiceTypeId=1)
		----IF (@ServiceTypeId IN (1,2,3))
		----ATENCIÓN SE CAMBIA ESTO PARA DESDE LA FACTURACIÓN  2019-12-16, ESTARÁ INCLUIDO EN EL CONTRATO PARA PERNOCTAS 

		--BEGIN
		--	INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
		--	RETURN
		--END

		--INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
		--RETURN
	END
		
	IF (@CompanyId = 70 AND @BillingToCompany = 70 AND @DateService < '2020-01-01') --INTERJET
	BEGIN
		BEGIN --SE DEJA ESTA REGLA COMO ESTABA INICIALMENTE PARA NO AFECTAR LA FACTURACION DEL 31 DE DICIEMBRE HACIA ATRÁS 
	        IF (@ServiceTypeId IN(1,2,3)) --PNTA		
	        BEGIN		
	            INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)		
	            RETURN		
	        END		
	        INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)		
	        RETURN		
	    END
	END
			
	IF (@CompanyId = 69 AND @BillingToCompany = 69) --SARPA
	BEGIN
		
		DECLARE @CleaningActivity INT = (SELECT COUNT(1) FROM CIOServicios.DetalleServicio WHERE EncabezadoServicioId = @ServiceHeaderId AND TipoActividadId = 24 AND Activo = 1 )

		IF (@CleaningActivity = 0 AND @ServiceTypeId IN (2,3,4) /*Pernocta*/)
		   BEGIN -- SI NO EXISTE ACTIVIDAD LIMPIEZA Y ES UNA PERNOCTA
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)	
				RETURN 
		   END

        IF (@ServiceTypeId NOT IN (2,3,4))
		   BEGIN
				 INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
		   END
		 
		RETURN
	END

	IF (@CompanyId IN (60, 69, 37) AND @BillingToCompany = 90) -- VIVA COLOMBIA, SARPA, SATENA A FASTCOLOMBIA
	BEGIN
		IF (CIOServicios.UFN_CIO_InternationalFlight(@AirportId, @DestinationId) = 1)
		BEGIN
			SET @ExtraText = ' INTERNACIONAL'
		END

		INSERT	@Result
		SELECT	StartTime
			,	FinalTime
			,	IsAdditionalService
			,	AdditionalAmount
			,	CONCAT(AdditionalService, @ExtraText) AdditionalService
		FROM	[CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)

		RETURN
	END

	IF (@CompanyId = 192 AND @BillingToCompany = 192) --VIVA PERU
	BEGIN
		INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
		RETURN
	END

	IF (@CompanyId = 64 AND @BillingToCompany = 1) --DELTA
	BEGIN
		INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
		RETURN
	END

	IF (@CompanyId = 65 AND @BillingToCompany = 1) --AEROPOSTAL		
	BEGIN
		INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
		RETURN
	END

	IF(@CompanyId IN (/*7 inactivo,*/44)) --LATAM LAN/AIRES                              
	BEGIN
		IF (@DateService < '2017-02-01')
		BEGIN
			IF (@ServiceTypeId NOT IN (2,13,3,4))
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
				RETURN
			END
			ELSE
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
				RETURN
			END
		END
		ELSE
		BEGIN
			--A PARTIR DE '2017-02-01' SE EMPIEZA A COBRAR DE ESTA MANERA
			IF (@ServiceTypeId IN (2,4,13,3)) --PERNOCTA, LIMPIEZA TERMINAL, PRIMER VUELO
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
				RETURN
			END
			IF (@ServiceTypeId = 1) --TRANSITOS INTERNACIONALES
			BEGIN
				--DECLARE	@AirportCountyId NUMERIC(18,0) = (	SELECT	top(1)	C.LugarId
				--											FROM		CIOServicios.EncabezadoServicio A 
				--											INNER JOIN	CIOGeografia.Aeropuertos C ON A.BaseId = C.AeropuertoId AND C.Activo = 1
				--											WHERE		A.Activo = 1
				--													AND A.BaseId = @AirportId		)

				--DECLARE	@DepartureCountryId NUMERIC(18,0) = (	SELECT	top(1)	C.LugarId
				--											FROM		CIOServicios.EncabezadoServicio A 
				--											INNER JOIN	CIOGeografia.Aeropuertos C ON A.BaseId = C.AeropuertoId AND C.Activo = 1
				--											WHERE		A.Activo = 1
				--													AND A.BaseId = @DestinationId		)

				IF (SELECT [CIOServicios].[UFN_CIO_InternationalFlight](@AirportId, @DestinationId)) = 1
				BEGIN
					--EN VUELOS INTERNACIONALES SE INCLUYE 1
					INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
					RETURN
				END
			END

			--PARA LOS DEMAS SE DEBE COBRAR ADICIONAL
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
			RETURN
		END
	END

	IF (@CompanyId = 72 AND @BillingToCompany = 56) --WINGO A AEROREPUBLICA
	BEGIN
		IF (@AirportId = 17 AND @ServiceTypeId IN(2,3,4)) --CTG
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
			RETURN
		END

		INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
		RETURN
	END

	IF(@ActivityTypeId = 15 AND @CompanyId IN (9, 56)) --COPA                          
	BEGIN
		IF (@AirportId = 1) --ADZ
		BEGIN
			IF (@ServiceTypeId IN (1,2,3,4)) --TTO Y PNTA
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
				RETURN
			END
			ELSE
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
				RETURN
			END
		END
		ELSE
		BEGIN
			IF (@ServiceTypeId IN (2,3,4)) --SOLO PNTA EL RESTO DE LAS BASES
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
				RETURN
			END
			ELSE
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
				RETURN
			END
		END
	END

	
	IF(@ActivityTypeId = 16 AND @CompanyId IN (9, 56)) --COPA                          
	BEGIN
		IF (@ServiceTypeId IN (2,3,4)) --SOLO SE INCLUYE 1 EN PNTA
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
			RETURN
		END
		ELSE
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
			RETURN
		END
	END

	IF(@CompanyId = 37 AND @BillingToCompany = 1 AND @AirportId IN (11,18)) --BGA Y CUC SATENA
	BEGIN
		IF (@ServiceTypeId IN(2,3,4))
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
			RETURN
		END
		ELSE
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
			RETURN
		END
	END 

	IF(@CompanyId = 81 AND @BillingToCompany = 81) --JET SMART
	BEGIN
		IF (@DateService >= '2020-01-01') --SE CONFIGURA DE ACUERDO A CORREO DE CLAUDIA MORALES 20200203
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
			RETURN
		END
		ELSE
		BEGIN
			IF (@ServiceTypeId IN (1,2,3,4)) --TTO Y PNTA
					BEGIN
						INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
						RETURN
					END
			ELSE
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
				RETURN
			END
		END
	END

	IF(@CompanyId = 205 AND @BillingToCompany = 205) --ARUBA AIRLINES ->2020-01-16
	BEGIN
		IF (@ServiceTypeId in (1,2,3,4)) --TTO Y PNTA
				BEGIN
					INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
					RETURN
				END
		ELSE
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
			RETURN
		END
	END

	IF (@CompanyId = 228 AND @BillingToCompany = 228) --GRAN COLOMBIA DE AVIACION (GCA)
	BEGIN
		INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
		RETURN
	END

	IF (@CompanyId = 255 AND @BillingToCompany = 255) --VIVAAEROBUS
	BEGIN
		IF (@DateService >= '2020-08-21') --SE CONFIGURA DE ACUERDO A CORREO DE CLAUDIA MORALES 20200203
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
			RETURN
		END
	END
		
	INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
	RETURN
END
